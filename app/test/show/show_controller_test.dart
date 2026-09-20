import 'package:app/show/show_config.dart';
import 'package:app/show/show_controller.dart';
import 'package:app/show/show_view_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'fake_show_scheduler.dart';
import 'fake_show_sim.dart';

/// R1 script: the human finishes 4th of 4 (quota 3) — eliminated.
final class _R1HumanLast extends FakeShowSim {
  _R1HumanLast({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 3);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(const PlayerFinished(tick: 1, playerId: 'bot-1'));
      emit(const PlayerFinished(tick: 2, playerId: 'bot-2'));
      emit(const PlayerFinished(tick: 3, playerId: 'bot-3'));
      emit(const PlayerFinished(tick: 4, playerId: 'solo-player'));
    }
    super.tickInputs(inputs);
  }
}

/// R1 script: the human finishes 1st — qualified.
final class _R1HumanFirst extends FakeShowSim {
  _R1HumanFirst({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 3);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(const PlayerFinished(tick: 1, playerId: 'solo-player'));
      emit(const PlayerFinished(tick: 2, playerId: 'bot-1'));
      emit(const PlayerFinished(tick: 3, playerId: 'bot-2'));
      emit(const PlayerFinished(tick: 4, playerId: 'bot-3'));
    }
    super.tickInputs(inputs);
  }
}

/// R1 script: three players finish on one tick behind the leader —
/// the trailing group enters whole (GDD § 7.1) and R2 gets 4
/// starters.
final class _R1SharedSlot extends FakeShowSim {
  _R1SharedSlot({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 3);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(const PlayerFinished(tick: 1, playerId: 'bot-1'));
      emit(const PlayerFinished(tick: 5, playerId: 'bot-2'));
      emit(const PlayerFinished(tick: 5, playerId: 'bot-3'));
      emit(const PlayerFinished(tick: 5, playerId: 'solo-player'));
    }
    super.tickInputs(inputs);
  }
}

/// R2 script: eliminates every bot whose id contains 'bot-2' first,
/// then 'bot-3' if present — leaves the human and bot-1 alive.
final class _R2EliminateTrailing extends FakeShowSim {
  _R2EliminateTrailing({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 3);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(PlayerEliminated(tick: 1, playerId: roster[2]));
      if (roster.length > 3) {
        emit(PlayerEliminated(tick: 2, playerId: roster[3]));
      }
    }
    super.tickInputs(inputs);
  }
}

/// FINAL script: the given champion crosses first; everyone else is
/// eliminated by the finish instant.
final class _FinalWonBy extends FakeShowSim {
  _FinalWonBy(
    this.champion, {
    required super.minigameId,
    required super.roster,
  }) : super(completeAfterTicks: 3);

  final PlayerId champion;

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(PlayerFinished(tick: 1, playerId: champion));
    }
    super.tickInputs(inputs);
  }
}

void main() {
  late FakeShowScheduler scheduler;
  final createdSims = <FakeShowSim>[];
  final builtRosters = <List<PlayerId>>[];
  final builtSeeds = <int>[];
  var championForFinal = 'solo-player';
  var r1Script = 'humanFirst';

  ShowController buildController({int showSeed = 11}) => ShowController(
    config: ShowConfig(showSeed: showSeed),
    scheduler: scheduler.call,
    simulationFactory: (slot, mapSeed, roster) {
      builtSeeds.add(mapSeed);
      builtRosters.add(List.of(roster));
      final sim = switch (slot.roundIndex) {
        1 => switch (r1Script) {
            'humanLast' =>
              _R1HumanLast(minigameId: slot.gameId, roster: roster),
            'sharedSlot' =>
              _R1SharedSlot(minigameId: slot.gameId, roster: roster),
            _ => _R1HumanFirst(minigameId: slot.gameId, roster: roster),
          },
        2 => _R2EliminateTrailing(minigameId: slot.gameId, roster: roster),
        _ => _FinalWonBy(
          championForFinal,
          minigameId: slot.gameId,
          roster: roster,
        ),
      };
      createdSims.add(sim);
      return (simulation: sim, map: Object());
    },
    botBrainFactory:
        (gameId,
            {required isFinal,
            required mapSeed,
            required botIds,
            required map}) => const {},
  );

  setUp(() {
    scheduler = FakeShowScheduler();
    createdSims.clear();
    builtRosters.clear();
    builtSeeds.clear();
    championForFinal = 'solo-player';
    r1Script = 'humanFirst';
  });

  /// Plays the mounted round to completion through its driver.
  void playMountedRound(ShowController controller) {
    final session = controller.currentRound;
    if (session == null) {
      fail('round must be mounted on ROUND_PLAY');
    }
    while (!session.driver.isRoundOver) {
      session.driver.tick();
    }
  }

  test('startShow_runs_intro_countdown_then_round_one_play', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();

    expect(controller.phase, ShowPhase.showIntro);
    expect(controller.countdownValue, showIntroSeconds);
    expect(controller.introGameName, 'Trap Race');

    scheduler.elapse(1000);
    expect(controller.countdownValue, 2);
    scheduler.elapse(2000);

    expect(controller.phase, ShowPhase.roundPlay);
    final session = controller.currentRound!;
    expect(session.minigameId, 'trap_race');
    expect(session.rosterIds, ['solo-player', 'bot-1', 'bot-2', 'bot-3']);
    expect(
      builtSeeds.single,
      ShowSchedule.mapSeedFor(showSeed: 11, roundIndex: 1),
    );
  });

  test('happy_path_chains_the_three_show_rounds', () {
    final controller = buildController();
    addTearDown(controller.dispose);
    final phases = <ShowPhase>[controller.phase];
    controller.addListener(() => phases.add(controller.phase));

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    playMountedRound(controller);

    expect(controller.phase, ShowPhase.qualifyFlash);
    expect(controller.verdictRoundIndex, 1);
    expect(controller.latestVerdict!.qualified, [
      'solo-player',
      'bot-1',
      'bot-2',
    ]);
    expect(controller.latestVerdict!.eliminated, ['bot-3']);

    scheduler.elapse(qualifyFlashSeconds * 1000);
    expect(controller.phase, ShowPhase.showIntro);
    expect(controller.roundIndex, 2);

    scheduler.elapse(showIntroSeconds * 1000);
    expect(controller.currentRound!.minigameId, 'hammer_dodge');
    expect(controller.currentRound!.rosterIds, <PlayerId>[
      'solo-player',
      'bot-1',
      'bot-2',
    ]);
    playMountedRound(controller);
    expect(controller.latestVerdict!.qualified, containsAll(<PlayerId>[
      'solo-player',
      'bot-1',
    ]));

    scheduler.elapse(qualifyFlashSeconds * 1000);
    expect(controller.phase, ShowPhase.showIntro);
    expect(controller.roundIndex, 3);
    expect(controller.introGameName, showFinalGameName);

    expect(
      phases.skip(1).contains(ShowPhase.lobby),
      isFalse,
      reason: 'the show runs uninterrupted (GDD § 1)',
    );
  });

  test('happy_path_crowns_the_final_champion_on_the_podium', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    for (var round = 1; round <= 3; round++) {
      scheduler.elapse(showIntroSeconds * 1000);
      playMountedRound(controller);
      scheduler.elapse(qualifyFlashSeconds * 1000);
    }

    expect(controller.latestVerdict!.isFinal, isTrue);
    expect(controller.latestVerdict!.champions, ['solo-player']);
    expect(controller.phase, ShowPhase.podium);
    expect(controller.champions, ['solo-player']);
    expect(controller.summary, isNull);
  });

  test('final_round_mounts_the_last_two_starters', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    for (var round = 1; round <= 2; round++) {
      scheduler.elapse(showIntroSeconds * 1000);
      playMountedRound(controller);
      scheduler.elapse(qualifyFlashSeconds * 1000);
    }
    scheduler.elapse(showIntroSeconds * 1000);

    final finalSession = controller.currentRound!;
    expect(finalSession.isFinal, isTrue);
    expect(finalSession.rosterIds, ['solo-player', 'bot-1']);
  });

  test(
    'human_eliminated_in_r1_summarizes_the_headless_show_outcome',
    () {
    r1Script = 'humanLast';
    championForFinal = 'bot-1';
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    playMountedRound(controller);
    expect(controller.latestVerdict!.eliminated, ['solo-player']);

    scheduler.elapse(qualifyFlashSeconds * 1000);

    expect(controller.phase, ShowPhase.lobby);
    final summary = controller.summary!;
    expect(summary.eliminatedInRound, 1);
    expect(summary.champions, ['bot-1']);
    // The headless chain built R2 (3 bots) and R3 (2 bots) with no
    // human seat — the same seed stream as a live show.
    expect(builtRosters[1], ['bot-1', 'bot-2', 'bot-3']);
    expect(
      builtRosters[2],
      anyOf(
        equals(<PlayerId>['bot-1', 'bot-2']),
        equals(<PlayerId>['bot-1', 'bot-3']),
      ),
      reason: 'R2 leaves two survivors of the scripted eliminations',
    );    expect(
      builtSeeds[1],
      ShowSchedule.mapSeedFor(showSeed: 11, roundIndex: 2),
    );
    expect(
      builtSeeds[2],
      ShowSchedule.mapSeedFor(showSeed: 11, roundIndex: 3),
    );
  });

  test('shared_qualification_cascade_feeds_extra_starter_to_r2', () {
    r1Script = 'sharedSlot';
    championForFinal = 'bot-1';
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    playMountedRound(controller);
    expect(controller.latestVerdict!.qualified, hasLength(4));

    scheduler
      ..elapse(qualifyFlashSeconds * 1000)
      ..elapse(showIntroSeconds * 1000);

    expect(controller.currentRound!.rosterIds, hasLength(4));
    expect(controller.currentRound!.minigameId, 'hammer_dodge');
  });

  test('final_lost_to_bot_still_ends_on_podium_with_bot_champion', () {
    championForFinal = 'bot-1';
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    for (var round = 1; round <= 3; round++) {
      scheduler.elapse(showIntroSeconds * 1000);
      playMountedRound(controller);
      scheduler.elapse(qualifyFlashSeconds * 1000);
    }

    expect(controller.latestVerdict!.champions, ['bot-1']);
    scheduler.elapse(qualifyFlashSeconds * 1000);
    expect(controller.phase, ShowPhase.podium);
    expect(controller.champions, ['bot-1']);
  });

  test('abandon_show_mid_round_resets_without_verdict_or_summary', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    expect(controller.phase, ShowPhase.roundPlay);

    controller.abandonShow();

    expect(controller.phase, ShowPhase.lobby);
    expect(controller.latestVerdict, isNull);
    expect(controller.summary, isNull);
    expect(controller.currentRound, isNull);
    expect(createdSims.single.disposed, isTrue);
  });

  test('play_again_starts_a_fresh_show_with_a_new_seed', () {
    final seeds = [11, 99];
    final controller = ShowController(
      config: ShowConfig(showSeed: seeds.first),
      scheduler: scheduler.call,
      showSeedFactory: () => seeds.removeAt(0),
      simulationFactory: (slot, mapSeed, roster) {
        builtSeeds.add(mapSeed);
        final sim = _R1HumanFirst(minigameId: slot.gameId, roster: roster);
        createdSims.add(sim);
        return (simulation: sim, map: Object());
      },
      botBrainFactory:
        (gameId,
            {required isFinal,
            required mapSeed,
            required botIds,
            required map}) => const {},
    );
    addTearDown(controller.dispose);

    controller.startShow();
    for (var round = 1; round <= 3; round++) {
      scheduler.elapse(showIntroSeconds * 1000);
      playMountedRound(controller);
      scheduler.elapse(qualifyFlashSeconds * 1000);
    }
    expect(controller.phase, ShowPhase.podium);

    controller.playAgain();

    expect(controller.phase, ShowPhase.showIntro);
    expect(controller.roundIndex, 1);
    expect(controller.summary, isNull);
    expect(controller.champions, isNull);
  });

  test('exit_to_home_from_podium_returns_to_a_clean_lobby', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    for (var round = 1; round <= 3; round++) {
      scheduler.elapse(showIntroSeconds * 1000);
      playMountedRound(controller);
      scheduler.elapse(qualifyFlashSeconds * 1000);
    }

    controller.exitToHome();

    expect(controller.phase, ShowPhase.lobby);
    expect(controller.champions, isNull);
    expect(controller.latestVerdict, isNull);
  });

  test('human_finish_ms_captured_per_race_round', () {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    expect(controller.humanFinishMs, isNull);
    playMountedRound(controller);

    // Human finished at tick 1: 1 / 60 Hz -> ~17 ms.
    expect(controller.humanFinishMs, 17);
  });
}
