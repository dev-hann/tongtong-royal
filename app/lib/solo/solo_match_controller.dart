import 'dart:async';

import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_round_driver.dart';
import 'package:app/solo/solo_round_session.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

export 'package:app/solo/solo_round_session.dart';

/// Delayed-callback seam: the controller's only clock. Production
/// wires a [Timer]; tests drive a fake virtual clock.
typedef SoloScheduler = void Function(Duration delay, VoidCallback callback);

/// GDD § 5 intro countdown, seconds.
const int soloIntroSeconds = 3;

/// Orchestrates a solo match (human vs bots, GDD § 9) over a
/// [ShellController]: plans the rounds ([planSoloRounds]), feeds the
/// intro/results screens their data, builds each round's simulation
/// and bot brains, and hands results to the shell after the domain
/// resolves them. Single-round flow (GDD § 2): ROUND_RESULTS is
/// terminal — [playAgain] starts a fresh match (fresh seeds,
/// ROUND_RESULTS -> LOBBY -> ROUND_INTRO), [exitToHome] returns to
/// the lobby for the shell's home screen. Owns no rules — placements
/// and points come from the domain via [SoloRoundDriver.finish];
/// timers only through the injected [SoloScheduler].
final class SoloMatchController extends ChangeNotifier {
  /// Creates the controller for [shell].
  SoloMatchController({
    required this.shell,
    this.config = const SoloMatchConfig(),
    this.registry = const MinigameRegistry(),
    RoundSimulationFactory? simulationFactory,
    SoloScheduler? scheduler,
  }) : simulationFactory = simulationFactory ?? defaultRoundSimulationFactory,
       scheduler = scheduler ?? _timerScheduler {
    _seats = [
      (id: config.humanId, nickname: config.humanNickname),
      ...BotFactory.buildBotRoster(1),
    ];
    _replan();
    shell.addListener(_onShellChanged);
  }

  /// The shell whose phases this controller orchestrates.
  final ShellController shell;

  /// Match configuration (seats, rounds, seed family).
  final SoloMatchConfig config;

  /// Registered minigames (specs + domain judging).
  final MinigameRegistry registry;

  /// Builds each round's simulation (overridable in tests).
  final RoundSimulationFactory simulationFactory;

  /// The controller's only clock.
  final SoloScheduler scheduler;

  late final List<({PlayerId id, String nickname})> _seats;
  List<SoloRoundPlan> _rounds = [];

  SoloRoundSession? _session;
  int _countdown = 0;
  int _generation = 0;

  /// All seats: the human first, then the bot fill (GDD § 9.1).
  List<({PlayerId id, String nickname})> get seats => List.unmodifiable(_seats);

  /// Seat ids in [seats] order.
  List<PlayerId> get rosterIds => [for (final seat in _seats) seat.id];

  /// The human seat id.
  PlayerId get humanId => config.humanId;

  /// Current match plan (regenerated per replay).
  List<SoloRoundPlan> get rounds => List.unmodifiable(_rounds);

  /// The round currently set up or running; null outside ROUND_PLAY.
  SoloRoundSession? get currentRound => _session;

  /// Intro display name of the upcoming round's minigame.
  String get introName => registry.byId(_upcomingId).spec.name;

  /// Intro one-line rule of the upcoming round's minigame.
  String get introRule => registry.byId(_upcomingId).spec.oneLineRule;

  MiniGameId get _upcomingId =>
      _rounds[shell.roundIndex.clamp(0, _rounds.length - 1)].minigameId;

  /// Seconds left on the intro countdown (GDD § 5).
  int get countdownValue => _countdown;

  /// Seconds left in the running round, from the driver's timeout
  /// budget (`timeoutTicks - tickCount` at the fixed rate); null
  /// outside ROUND_PLAY.
  int? get remainingSeconds {
    final driver = _session?.driver;
    if (driver == null) {
      return null;
    }
    final left = (driver.timeoutTicks - driver.tickCount).clamp(
      0,
      driver.timeoutTicks,
    );
    return (left * PhysicsConsts.fixedDt).ceil();
  }

  /// Display name of the latest round's minigame for the results
  /// header; null when no round result exists yet.
  String? get resultsMinigameName {
    final id = shell.latestRoundResult?.minigameId;
    return id == null ? null : registry.byId(id).spec.name;
  }

  /// LOBBY -> ROUND_INTRO: starts the solo match.
  void startSolo() {
    if (shell.phase != RoundPhase.lobby) {
      return;
    }
    shell.startMatch();
  }

  /// ROUND_RESULTS -> LOBBY -> ROUND_INTRO with a regenerated plan
  /// (fresh map seed, GDD § 5 PLAY AGAIN). Illegal-transitions
  /// propagate (nothing swallowed).
  void playAgain() {
    if (shell.phase != RoundPhase.roundResults) {
      return;
    }
    shell.toLobby();
    _generation++;
    _replan();
    shell.startMatch();
    notifyListeners();
  }

  /// ROUND_RESULTS -> LOBBY; the shell shows its home screen (GDD §
  /// 5 HOME). Illegal transitions propagate.
  void exitToHome() {
    if (shell.phase != RoundPhase.roundResults) {
      return;
    }
    _generation++;
    _replan();
    shell.toLobby();
    notifyListeners();
  }

  /// ROUND_PLAY -> LOBBY with no result (GDD § 7.11 solo abandon):
  /// releases the running round, replans a fresh match and returns
  /// the shell to the lobby for its home screen. Abandoned races
  /// never reach ROUND_RESULTS, so no stats are recorded.
  void abandonMatch() {
    // Abandoning works from the countdown and from play — anywhere a
    // round is in flight (ux-checklist back matrix).
    if (shell.phase != RoundPhase.roundPlay &&
        shell.phase != RoundPhase.roundIntro) {
      return;
    }
    _generation++;
    _releaseRound();
    _replan();
    shell.abandonMatch();
    notifyListeners();
  }

  void _replan() {
    _rounds = planSoloRounds(
      rounds: config.rounds,
      pool: registry.pool,
      matchSeed: config.matchSeed,
      generation: _generation,
    );
  }

  void _onShellChanged() {
    switch (shell.phase) {
      case RoundPhase.roundIntro:
        _startIntro();
      case RoundPhase.roundPlay:
        _startRound();
      case RoundPhase.roundResults:
      case RoundPhase.podium:
        _releaseRound();
      case RoundPhase.lobby:
        break;
    }
    notifyListeners();
  }

  void _startIntro() {
    _countdown = soloIntroSeconds;
    _scheduleIntroTick();
  }

  void _scheduleIntroTick() {
    scheduler(const Duration(seconds: 1), () {
      if (shell.phase != RoundPhase.roundIntro) {
        return; // stale timer (round already left intro)
      }
      if (_countdown > 1) {
        _countdown--;
        notifyListeners();
        _scheduleIntroTick();
        return;
      }
      shell.startPlay();
    });
  }

  void _startRound() {
    final roundIndex = shell.roundIndex;
    final plan = _rounds[roundIndex];
    final game = registry.byId(plan.minigameId);
    final map = _mapFor(plan.minigameId, plan.mapSeed);
    final brains = <PlayerId, BotBrain>{
      for (var i = 1; i < _seats.length; i++)
        _seats[i].id: BotFactory.forGame(
          plan.minigameId,
          seed: plan.mapSeed * _seats.length + i,
          map: map,
        ),
    };
    final driver = SoloRoundDriver(
      simulation: simulationFactory(plan.minigameId, plan.mapSeed, rosterIds),
      game: game,
      roundIndex: roundIndex,
      roster: rosterIds.toSet(),
      humanId: config.humanId,
      brains: brains,
      map: map,
      onRoundComplete: shell.endRound,
    );
    _session = SoloRoundSession(
      driver: driver,
      simulation: driver.simulation,
      map: map,
      minigameId: plan.minigameId,
      humanId: config.humanId,
      rosterIds: rosterIds,
    );
  }

  void _releaseRound() {
    _session?.driver.dispose();
    _session = null;
  }

  /// Map binding mirroring [defaultRoundSimulationFactory] (the
  /// factory builds sims from these same constructors; bots and the
  /// renderer need the map data alongside the simulation).
  Object _mapFor(MiniGameId minigameId, int mapSeed) => switch (minigameId) {
    'trap_race' => CourseMap.trapRace(mapSeed),
    _ => throw ArgumentError.value(
      minigameId,
      'minigameId',
      'no solo map binding',
    ),
  };

  static void _timerScheduler(Duration delay, VoidCallback callback) {
    Timer(delay, callback);
  }

  @override
  void dispose() {
    shell.removeListener(_onShellChanged);
    _releaseRound();
    super.dispose();
  }
}
