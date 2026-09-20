library show_controller;

import 'dart:async';

import 'package:app/show/show_config.dart';
import 'package:app/show/show_round_session.dart';
import 'package:app/show/show_session_builder.dart';
import 'package:app/show/show_simulation_factory.dart';
import 'package:app/show/show_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

part 'show_controller_commands.dart';

/// Delayed-callback seam: the controller's only clock. Production
/// wires a [Timer]; tests drive a fake virtual clock (docs/03 §
/// 10.2.5).
/// Delayed-callback seam: the controller's only clock. Production
/// wires a [Timer]; tests drive a fake virtual clock (docs/03 §
/// 10.2.5).
typedef ShowScheduler = void Function(Duration delay, VoidCallback callback);

/// Orchestrates one solo show (human + bot fill, GDD v2 § 1) over a
/// `ShowStateMachine` and `ShowSchedule`: chains the three rounds —
/// intro countdown, live round (simulation + bot brains + human
/// input), domain qualification verdict, QUALIFY_FLASH — into the
/// crown podium, or into the elimination summary when the human
/// falls mid-show (GDD v2 § 7.3: remaining rounds resolve instantly
/// through the SAME runtime headlessly, fixed dt, same seed chain).
///
/// Owns no rules — verdicts come from the domain via
/// `resolveQualificationRound`; the schedule/quota/seed chain come
/// from `shared/domain`. Timers only through the injected
/// [ShowScheduler]; abandonment (GDD v2 § 7.4) records nothing.
final class ShowController extends ChangeNotifier {
  /// Creates a controller for a solo show.
  ShowController({
    this.config = const ShowConfig(),
    this.schedule = ShowSchedule.standard,
    this.registry = const MinigameRegistry([TrapRace(), HammerDodge()]),
    ShowSimulationFactory? simulationFactory,
    ShowBotBrainFactory? botBrainFactory,
    ShowScheduler? scheduler,
    int Function()? showSeedFactory,
  }) : simulationFactory = simulationFactory ?? defaultShowSimulationFactory,
       botBrainFactory = botBrainFactory ?? defaultShowBotBrainFactory,
       scheduler = scheduler ?? _timerScheduler,
       showSeedFactory = showSeedFactory ?? _defaultSeedFactory(config) {
    _seats = config.buildSeats();
    _field = [for (final seat in _seats) seat.id];
    _machine = ShowStateMachine();
  }

  /// Show configuration (human seat, seed family).
  final ShowConfig config;

  /// The show structure (slots, quotas).
  final ShowSchedule schedule;

  /// Registered minigames (specs + domain judging).
  final MinigameRegistry registry;

  /// Builds each round's simulation + map (overridable in tests).
  final ShowSimulationFactory simulationFactory;

  /// Builds each round's bot brains (overridable in tests).
  final ShowBotBrainFactory botBrainFactory;

  /// The controller's only clock.
  final ShowScheduler scheduler;

  /// Pulls a fresh show seed at every [startShow] (GDD v2 § 6:
  /// wall-clock in production, injectable in tests; defaults to the
  /// config seed so a config replays deterministically).
  final int Function() showSeedFactory;

  late final List<ShowSeat> _seats;
  late final ShowStateMachine _machine;
  List<PlayerId> _field = const [];
  ShowRoundSession? _session;
  int _countdown = 0;
  int _showSeed = 0;
  int _verdictRoundIndex = 0;
  QualificationResult? _verdict;
  List<PlayerId>? _champions;
  ShowSummary? _summary;
  int? _humanFinishMs;

  /// The current show phase.
  ShowPhase get phase => _machine.phase;

  /// One-based index of the current (upcoming or running) round.
  int get roundIndex => _machine.roundIndex;

  /// Rounds per show (GDD v2 § 1: exactly 3).
  int get roundCount => ShowSchedule.roundCount;

  /// All seats: the human first, then the bot fill (GDD v2 § 9).
  List<ShowSeat> get seats => List.unmodifiable(_seats);

  /// Starters of the current round, human first.
  List<PlayerId> get field => List.unmodifiable(_field);

  /// The round currently mounted for play; null outside ROUND_PLAY.
  ShowRoundSession? get currentRound => _session;

  /// Seconds left on the intro countdown (GDD v2 § 5).
  int get countdownValue => _countdown;

  /// The latest qualification verdict, shown during QUALIFY_FLASH.
  QualificationResult? get latestVerdict => _verdict;

  /// One-based round index the latest verdict belongs to.
  int get verdictRoundIndex => _verdictRoundIndex;

  /// Crown winners once the FINAL resolved; null before the podium.
  List<PlayerId>? get champions => _champions;

  /// Terminal outcome after a mid-show elimination (GDD v2 § 7.3);
  /// null otherwise.
  ShowSummary? get summary => _summary;

  /// The human's finish time in ms for the latest race round (null
  /// when they did not finish or no race ran).
  int? get humanFinishMs => _humanFinishMs;

  void _beginIntro() {
    _countdown = showIntroSeconds;
    _scheduleIntroTick();
    notifyListeners();
  }

  void _scheduleIntroTick() {
    scheduler(const Duration(seconds: 1), () {
      if (_machine.phase != ShowPhase.showIntro) {
        return; // stale timer (show already left the intro)
      }
      if (_countdown > 1) {
        _countdown--;
        notifyListeners();
        _scheduleIntroTick();
        return;
      }
      _machine.startRoundPlay();
      _startRoundLive();
      notifyListeners();
    });
  }

  void _startRoundLive() {
    final roundIndex = _machine.roundIndex;
    final slot = schedule.slotFor(roundIndex);
    final mapSeed = ShowSchedule.mapSeedFor(
      showSeed: _showSeed,
      roundIndex: roundIndex,
    );
    final starters = List<PlayerId>.of(_field);
    _humanFinishMs = null;
    _session = buildShowRoundSession(
      config: config,
      registry: registry,
      simulationFactory: simulationFactory,
      botBrainFactory: botBrainFactory,
      slot: slot,
      roundIndex: roundIndex,
      mapSeed: mapSeed,
      starters: starters,
      onRoundComplete: _onRoundResolved,
    );
  }

  void _onRoundResolved(QualificationResult result) {
    final session = _session;
    if (session != null && session.humanId != null) {
      final tick = session.driver.finishTickOf(session.humanId!);
      _humanFinishMs = tick == null
          ? null
          : (tick * PhysicsConsts.fixedDt * 1000).round();
    }
    _releaseRound();
    _machine.endRound();
    _verdict = result;
    _verdictRoundIndex = _machine.roundsCompleted;
    _scheduleFlashAdvance();
    notifyListeners();
  }

  void _scheduleFlashAdvance() {
    scheduler(const Duration(seconds: qualifyFlashSeconds), () {
      if (_machine.phase != ShowPhase.qualifyFlash) {
        return; // stale timer (show abandoned during the flash)
      }
      _advanceAfterFlash();
    });
  }

  void _advanceAfterFlash() {
    final verdict = _verdict;
    if (verdict == null) {
      throw StateError('flash advance without a verdict');
    }
    if (verdict.isFinal) {
      _champions = List<PlayerId>.of(verdict.champions);
      _machine.toPodium();
      notifyListeners();
      return;
    }
    if (verdict.eliminated.contains(config.humanId)) {
      // GDD v2 § 7.3: the human is out — the remaining rounds resolve
      // instantly through the same runtime (headless drivers, fixed
      // dt, the show's seed chain continues), then the summary
      // replaces the rest of the show.
      final champions = resolveHeadlessShow(
        config: config,
        schedule: schedule,
        registry: registry,
        simulationFactory: simulationFactory,
        botBrainFactory: botBrainFactory,
        field: verdict.qualified,
        fromRound: _machine.roundsCompleted + 1,
        showSeed: _showSeed,
      );
      _summary = ShowSummary(
        eliminatedInRound: _verdictRoundIndex,
        champions: champions,
      );
      _machine.abandon();
      notifyListeners();
      return;
    }
    _field = List<PlayerId>.of(verdict.qualified);
    _machine.nextRound();
    _beginIntro();
  }

  void _releaseRound() {
    _session?.driver.dispose();
    _session = null;
  }

  void _clearShowOutcome() {
    _releaseRound();
    _verdict = null;
    _verdictRoundIndex = 0;
    _champions = null;
    _summary = null;
    _humanFinishMs = null;
    _field = [for (final seat in _seats) seat.id];
    notifyListeners();
  }

  static void _timerScheduler(Duration delay, VoidCallback callback) {
    Timer(delay, callback);
  }

  static int Function() _defaultSeedFactory(ShowConfig config) {
    return () => config.showSeed;
  }

  @override
  void dispose() {
    _releaseRound();
    super.dispose();
  }
}
