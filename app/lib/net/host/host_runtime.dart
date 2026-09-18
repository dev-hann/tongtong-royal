import 'dart:async';

import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/infra/net_client.dart';
import 'package:app/infra/net_log.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One snapshot every Nth simulation tick:
/// `PhysicsConsts.tickRate ~/ PhysicsConsts.snapshotRateHz` — 60 Hz sim
/// → 20 Hz snapshots → every 3rd tick (network doc § 1).
const int snapshotEveryTicks =
    PhysicsConsts.tickRate ~/ PhysicsConsts.snapshotRateHz;

/// Builds the round simulation for a minigame/seed pair. The default
/// builds the Trap Race course from the seed (architecture doc § 3:
/// layout lives in the app package, selected by `mapSeed`).
typedef RaceSimulationFactory = RaceSimulation Function(
  MiniGameId minigameId,
  int mapSeed,
  Iterable<PlayerId> roster,
);

/// Default factory: the built-in Trap Race course variant for [mapSeed].
RaceSimulation defaultRaceSimulationFactory(
  MiniGameId minigameId,
  int mapSeed,
  Iterable<PlayerId> roster,
) => RaceSimulation(map: CourseMap.trapRace(mapSeed), playerIds: roster);

/// Host-authoritative round runtime: binds a [NetClient] transport to
/// a [RaceSimulation] (architecture doc § 4).
///
/// Owns the fixed-dt tick loop (driven manually via [advance] — no
/// real timers), the latest-input-per-player buffer (later `seq`
/// wins, network doc § 1), the 20 Hz snapshot broadcast, progress
/// sampling and the round lifecycle. Judges nothing: placements come
/// from the domain [game]'s `resolve` only.
///
/// Currently bound to [TrapRace], the only race-archetype minigame;
/// widen the seam inside `shared/domain` when a second one lands.
final class HostRuntime {
  /// Creates a runtime for [roster] (every seat, including idle and
  /// disconnected bodies — network doc § 5.2).
  HostRuntime({
    required this.client,
    required this.game,
    required Set<PlayerId> roster,
    RaceSimulationFactory? simulationFactory,
    NetLog? log,
  }) : roster = Set.unmodifiable(roster),
        simulationFactory = simulationFactory ?? defaultRaceSimulationFactory,
        _log = log ?? const SilentNetLog() {
    if (roster.isEmpty) {
      throw ArgumentError.value(roster, 'roster', 'must not be empty');
    }
    _memberInputsSubscription = client.memberInputs.listen(_onMemberInput);
  }

  /// Transport used for every host broadcast.
  final NetClient client;

  /// Diagnostic sink for dropped (unattributed) member inputs.
  final NetLog _log;

  /// Domain rules; the runtime itself judges nothing.
  final TrapRace game;

  /// Every seat for the round, including idle/disconnected bodies.
  final Set<PlayerId> roster;

  /// Builds each round's simulation from the minigame/seed pair.
  final RaceSimulationFactory simulationFactory;
  final PlayerInputState _idleInput = PlayerInputState();
  final StreamController<RoundResult> _roundCompleteController =
      StreamController<RoundResult>.broadcast(sync: true);

  RaceSimulation? _simulation;
  StreamSubscription<RoundEvent>? _eventsSubscription;
  StreamSubscription<PlayerInputMessage>? _memberInputsSubscription;
  final List<RoundEvent> _roundEvents = <RoundEvent>[];
  final List<ProgressSample> _samples = <ProgressSample>[];
  final Map<PlayerId, PlayerInputMessage> _latestInput = {};
  final Map<PlayerId, int> _lastInputSeq = {};

  bool _roundActive = false;
  int _tick = 0;
  int _roundStartTick = 0;
  int _roundIndex = -1;
  double _accumulator = 0;

  /// Fires once per finished round with the domain-resolved result.
  Stream<RoundResult> get onRoundComplete => _roundCompleteController.stream;

  /// Whether a round is currently simulated.
  bool get isRoundActive => _roundActive;

  /// Host global tick; never resets mid-match (network doc § 1).
  int get currentTick => _tick;

  /// Round timeout expressed in simulation ticks, derived from the
  /// minigame spec's `timeoutMs` and the fixed tick rate.
  int get roundTimeoutTicks =>
      (game.spec.timeoutMs * PhysicsConsts.tickRate / 1000).round();

  /// Starts a round: builds the simulation, then broadcasts
  /// `RoundStarting` (network doc § 4). Throws [StateError] when a
  /// round is already running.
  void startRound(int roundIndex, MiniGameId minigameId, int mapSeed) {
    if (_roundActive) {
      throw StateError('a round is already running');
    }
    final simulation = simulationFactory(minigameId, mapSeed, roster);
    _roundEvents.clear();
    _samples.clear();
    _latestInput.clear();
    _lastInputSeq.clear();
    _accumulator = 0;
    _eventsSubscription = simulation.events.listen(_roundEvents.add);
    _simulation = simulation;
    _roundIndex = roundIndex;
    _roundStartTick = _tick;
    _roundActive = true;
    client.sendHost(
      RoundStarting(
        roundIndex: roundIndex,
        minigameId: minigameId,
        mapSeed: mapSeed,
        timeoutMs: game.spec.timeoutMs,
      ),
    );
  }

  /// Offers one attributed member input sample. Later `seq` wins per
  /// player; stale `seq` and samples from outside the roster or
  /// outside a running round are dropped (network doc § 1, § 6).
  ///
  /// The [playerId] comes from the server stamp on
  /// [PlayerInputMessage.playerId] (network doc § 1 "Input
  /// attribution") — the bridge [_onMemberInput] feeds this buffer
  /// from `NetClient.memberInputs` keyed by that identity.
  void submitMemberInput(PlayerId playerId, PlayerInputMessage input) {
    if (!_roundActive || !roster.contains(playerId)) {
      return;
    }
    final lastSeq = _lastInputSeq[playerId];
    if (lastSeq != null && input.seq <= lastSeq) {
      return;
    }
    _lastInputSeq[playerId] = input.seq;
    _latestInput[playerId] = input;
  }

  /// Routes server-relayed member samples into the input buffer. The
  /// stamped [PlayerInputMessage.playerId] is authoritative; samples
  /// without one (unattributed) are dropped and logged — never fed to
  /// a guessed body.
  void _onMemberInput(PlayerInputMessage input) {
    final playerId = input.playerId;
    if (playerId == null) {
      _log.warn(
        'dropped unattributed member input seq ${input.seq} '
        '(network doc § 1: server must stamp the sending connection)',
      );
      return;
    }
    submitMemberInput(playerId, input);
  }

  /// Advances host time by [dtSeconds] on a fixed-dt accumulator:
  /// whole [PhysicsConsts.fixedDt] slices tick the simulation, the
  /// remainder carries over. No-op between rounds. Throws
  /// [ArgumentError] for negative or non-finite input.
  void advance(double dtSeconds) {
    if (!dtSeconds.isFinite || dtSeconds.isNegative) {
      throw ArgumentError.value(
        dtSeconds,
        'dtSeconds',
        'must be finite and non-negative',
      );
    }
    if (!_roundActive) {
      return;
    }
    _accumulator += dtSeconds;
    while (_roundActive && _accumulator >= PhysicsConsts.fixedDt) {
      _accumulator -= PhysicsConsts.fixedDt;
      _tickOnce();
    }
  }

  /// Releases the runtime: event subscription, member-input bridge,
  /// simulation and the completion stream.
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    await _memberInputsSubscription?.cancel();
    _memberInputsSubscription = null;
    _simulation?.dispose();
    _simulation = null;
    _roundActive = false;
    await _roundCompleteController.close();
  }

  void _tickOnce() {
    final simulation = _simulation!;
    final inputs = <PlayerId, PlayerInputState>{
      for (final id in roster) id: _inputFor(id),
    };
    simulation.tickInputs(inputs);
    _tick++;
    if (_tick % snapshotEveryTicks == 0) {
      _broadcastSnapshot(simulation);
    }
    if ((_tick - _roundStartTick) % PhysicsConsts.progressSampleIntervalTicks
        == 0) {
      _sampleProgress(simulation);
    }
    _maybeEndRound();
  }

  PlayerInputState _inputFor(PlayerId playerId) {
    final message = _latestInput[playerId];
    if (message == null) {
      return _idleInput; // network doc § 5.2: idle body, zero input
    }
    return PlayerInputState(
      moveDir: Vector2(message.moveX, message.moveY),
      jumpPressed: message.jump,
      dashPressed: message.dash,
    );
  }

  void _broadcastSnapshot(RaceSimulation simulation) {
    final players = <PlayerState>[];
    for (final id in roster) {
      final body = simulation.bodyOf(id);
      players.add(
        PlayerState(
          playerId: id,
          x: body.position.x,
          y: body.position.y,
          angle: body.angle,
          vx: body.linearVelocity.x,
          vy: body.linearVelocity.y,
        ),
      );
    }
    client.sendHost(Snapshot(tick: _tick, players: players));
  }

  void _sampleProgress(RaceSimulation simulation) {
    final spawnX = simulation.map.spawnPoint.x;
    for (final id in roster) {
      _samples.add(
        ProgressSample(
          tick: _tick,
          playerId: id,
          distance: simulation.bodyOf(id).position.x - spawnX,
        ),
      );
    }
  }

  void _maybeEndRound() {
    if (!_roundActive) {
      return;
    }
    final finishers = <PlayerId>{
      for (final event in _roundEvents.whereType<PlayerFinished>())
        event.playerId,
    };
    final allFinished = roster.every(finishers.contains);
    final roundTicks = _tick - _roundStartTick;
    if (!allFinished && roundTicks < roundTimeoutTicks) {
      return;
    }
    _endRound();
  }

  void _endRound() {
    final simulation = _simulation!;
    final result = game.resolve(
      RoundEvents(roundIndex: _roundIndex, events: _roundEvents.toList()),
      TrapRaceInput(roster: roster, samples: _samples.toList()),
    );
    _roundActive = false;
    _simulation = null;
    unawaited(
      _eventsSubscription?.cancel().then((_) {
        simulation.dispose();
      }),
    );
    _eventsSubscription = null;
    client.sendHost(RoundResultsMessage(roundResult: result));
    _roundCompleteController.add(result);
  }
}
