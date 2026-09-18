import 'dart:async';

import 'package:app/game/round_simulation.dart';
import 'package:app/infra/net_client.dart';
import 'package:app/infra/net_log.dart';
import 'package:app/net/host/round_resolver.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One snapshot every Nth simulation tick:
/// `PhysicsConsts.tickRate ~/ PhysicsConsts.snapshotRateHz` — 60 Hz sim
/// → 20 Hz snapshots → every 3rd tick (network doc § 1).
const int snapshotEveryTicks =
    PhysicsConsts.tickRate ~/ PhysicsConsts.snapshotRateHz;

/// Host-authoritative round runtime: binds a [NetClient] transport to
/// any minigame's [RoundSimulation] (architecture doc § 4). Owns the
/// fixed-dt tick loop (driven manually via [advance] — no real
/// timers), the latest-input-per-player buffer (later `seq` wins,
/// network doc § 1), the 20 Hz snapshot broadcast, progress sampling
/// and the round lifecycle. Judges nothing: placements come from the
/// domain game's `resolve` only, reached through [resolveRound].
final class HostRuntime {
  /// Creates a runtime for [roster] (every seat, including idle and
  /// disconnected bodies — network doc § 5.2).
  HostRuntime({
    required this.client,
    required Set<PlayerId> roster,
    this.registry = const MinigameRegistry(),
    RoundSimulationFactory? simulationFactory,
    NetLog? log,
  }) : roster = Set.unmodifiable(roster),
       simulationFactory = simulationFactory ?? defaultRoundSimulationFactory,
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

  /// Registered minigames; each round's game is looked up by id.
  final MinigameRegistry registry;

  /// Every seat for the round, including idle/disconnected bodies.
  final Set<PlayerId> roster;

  /// Builds each round's simulation from the minigame/seed pair.
  final RoundSimulationFactory simulationFactory;
  final PlayerInputState _idleInput = PlayerInputState();
  final StreamController<RoundResult> _roundCompleteController =
      StreamController<RoundResult>.broadcast(sync: true);

  RoundSimulation? _simulation;
  MiniGame? _game;
  int _timeoutTicks = 0;
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

  /// Round timeout in ticks for the started (or last) round's
  /// minigame spec. Throws [StateError] before any round started.
  int get roundTimeoutTicks {
    final game = _game;
    if (game == null) {
      throw StateError('no round started yet');
    }
    return timeoutTicksFor(game);
  }

  /// Ticks equivalent of a spec's `timeoutMs` at the fixed rate.
  static int timeoutTicksFor(MiniGame game) =>
      (game.spec.timeoutMs * PhysicsConsts.tickRate / 1000).round();

  /// Starts a round: resolves the domain game from [minigameId] via
  /// [registry], builds the simulation, then broadcasts
  /// `RoundStarting` (network doc § 4). Throws [StateError] when a
  /// round is already running, [ArgumentError] for an unknown id.
  void startRound(int roundIndex, MiniGameId minigameId, int mapSeed) {
    if (_roundActive) {
      throw StateError('a round is already running');
    }
    final game = registry.byId(minigameId);
    final simulation = simulationFactory(minigameId, mapSeed, roster);
    _roundEvents.clear();
    _samples.clear();
    _latestInput.clear();
    _lastInputSeq.clear();
    _accumulator = 0;
    _eventsSubscription = simulation.events.listen(_roundEvents.add);
    _simulation = simulation;
    _game = game;
    _timeoutTicks = timeoutTicksFor(game);
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
  /// outside a running round are dropped (network doc § 1, § 6). The
  /// [playerId] is the server stamp on [PlayerInputMessage.playerId];
  /// the bridge [_onMemberInput] feeds this buffer.
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
    if ((_tick - _roundStartTick) % PhysicsConsts.progressSampleIntervalTicks ==
        0) {
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

  void _broadcastSnapshot(RoundSimulation simulation) {
    final players = <PlayerState>[];
    for (final id in roster) {
      final pose = simulation.poseOf(id);
      if (pose == null) {
        continue; // eliminated (survival archetype): body is gone
      }
      players.add(
        PlayerState(
          playerId: id,
          x: pose.x,
          y: pose.y,
          angle: pose.angle,
          vx: pose.vx,
          vy: pose.vy,
        ),
      );
    }
    client.sendHost(Snapshot(tick: _tick, players: players));
  }

  /// Progress sampling is race-archetype only: sims without a course
  /// anchor (arenas) report none (hold time travels as events).
  void _sampleProgress(RoundSimulation simulation) {
    final anchorX = simulation.progressAnchorX;
    if (anchorX == null) {
      return;
    }
    for (final id in roster) {
      final x = simulation.poseOf(id)?.x;
      if (x == null) {
        continue;
      }
      _samples.add(
        ProgressSample(tick: _tick, playerId: id, distance: x - anchorX),
      );
    }
  }

  /// Round ends when the simulation declares itself complete (all
  /// finished / last standing / internal timeout) or on timeout.
  void _maybeEndRound() {
    if (!_roundActive) return;
    final simulation = _simulation!;
    final roundTicks = _tick - _roundStartTick;
    if (!simulation.isComplete && roundTicks < _timeoutTicks) {
      return;
    }
    _endRound();
  }

  void _endRound() {
    final simulation = _simulation!;
    final game = _game!;
    final result = resolveRound(
      game,
      RoundEvents(roundIndex: _roundIndex, events: _roundEvents.toList()),
      RoundData(roster: roster, progressSamples: _samples.toList()),
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
