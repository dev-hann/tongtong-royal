import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'fake_solo_scheduler.dart';
import 'fake_solo_sim.dart';

/// Fake sim that emits a full ranking script on its first tick so
/// the round resolves deterministically: the human wins.
final class _ScriptedSoloSim extends FakeSoloSim {
  _ScriptedSoloSim({required super.minigameId, required super.roster})
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

void main() {
  late ShellController shell;
  late FakeSoloScheduler scheduler;
  late SoloMatchController controller;
  final createdSims = <_ScriptedSoloSim>[];

  setUp(() {
    shell = ShellController();
    scheduler = FakeSoloScheduler();
    createdSims.clear();
    controller = SoloMatchController(
      shell: shell,
      config: const SoloMatchConfig(matchSeed: 11),
      scheduler: scheduler.call,
      simulationFactory: (minigameId, mapSeed, roster) {
        final sim = _ScriptedSoloSim(minigameId: minigameId, roster: roster);
        createdSims.add(sim);
        return sim;
      },
    );
    addTearDown(controller.dispose);
  });

  /// Steps the round to completion through the session driver.
  void playRound() {
    final session = controller.currentRound;
    expect(session, isNotNull, reason: 'round must be built on ROUND_PLAY');
    while (!session!.driver.isRoundOver) {
      session.driver.tick();
    }
  }

  test('roster seats the human plus three bots', () {
    expect(controller.rosterIds, ['solo-player', 'bot-1', 'bot-2', 'bot-3']);
    expect(controller.seats.first.nickname, 'You');
    expect(controller.seats[1].nickname, 'BOT 1');
  });

  test('plan is the single MVP minigame', () {
    expect(controller.rounds, hasLength(1));
    expect(controller.rounds.single.minigameId, 'trap_race');
  });

  test('full match: one round then terminal results (no auto-advance)', () {
    final phases = <RoundPhase>[shell.phase];
    shell.addListener(() => phases.add(shell.phase));

    controller.startSolo();
    final results = <RoundResult>[];
    shell.addListener(() {
      final result = shell.latestRoundResult;
      if (result != null && !results.contains(result)) {
        results.add(result);
      }
    });

    scheduler.elapse(3000); // intro countdown
    expect(shell.phase, RoundPhase.roundPlay);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);

    // Terminal: no scheduled advance ever fires.
    scheduler.elapse(600000);
    expect(shell.phase, RoundPhase.roundResults);
    expect(shell.roundIndex, 1, reason: 'one round completed');

    expect(results, hasLength(1));
    expect(results.single.roundIndex, 0);
    // 4 players ranked: points 4/3/2/1 (GDD § 2), human first.
    expect(results.single.placements, hasLength(4));
    expect(results.single.placements.first.playerId, 'solo-player');
    expect(results.single.placements.map((p) => p.points).toList(), [
      4,
      3,
      2,
      1,
    ]);

    expect(deduped(phases), [
      RoundPhase.lobby,
      RoundPhase.roundIntro,
      RoundPhase.roundPlay,
      RoundPhase.roundResults,
    ]);

    // Every fake simulation was released after its round.
    for (final sim in createdSims) {
      expect(sim.inputLog, isNotEmpty);
    }
  });

  test('intro countdown ticks down and starts play at zero', () {
    controller.startSolo();
    expect(shell.phase, RoundPhase.roundIntro);
    expect(controller.countdownValue, 3);

    scheduler.elapse(1000);
    expect(shell.phase, RoundPhase.roundIntro);
    expect(controller.countdownValue, 2);

    scheduler.elapse(1000);
    expect(controller.countdownValue, 1);
    expect(shell.phase, RoundPhase.roundIntro);

    scheduler.elapse(1000);
    expect(shell.phase, RoundPhase.roundPlay);
  });

  test('playAgain starts a fresh match with fresh map seed', () {
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);
    final firstSeed = controller.rounds.single.mapSeed;

    controller.playAgain();

    expect(shell.phase, RoundPhase.roundIntro);
    expect(shell.roundIndex, 0);
    expect(controller.rounds.single.mapSeed, isNot(firstSeed));

    // And the fresh match plays another full round.
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);
    expect(createdSims, hasLength(2));
  });

  test('exitToHome returns to the lobby for a fresh match', () {
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);

    controller.exitToHome();

    expect(shell.phase, RoundPhase.lobby);
    expect(shell.roundIndex, 0);
    expect(shell.latestRoundResult, isNull);
    expect(shell.roundResults, isEmpty);
  });
  test('abandonMatch quits mid-round to the lobby without a result', () {
    controller.startSolo();
    scheduler.elapse(3000);
    expect(shell.phase, RoundPhase.roundPlay);
    expect(controller.currentRound, isNotNull);
    final oldSeed = controller.rounds.single.mapSeed;

    controller.abandonMatch();

    expect(shell.phase, RoundPhase.lobby);
    // No round result was recorded (abandoned races record no stats).
    expect(shell.latestRoundResult, isNull);
    expect(shell.roundResults, isEmpty);
    // The round session was released and the next match replans.
    expect(controller.currentRound, isNull);
    expect(controller.rounds.single.mapSeed, isNot(oldSeed));

    // And the fresh match plays from the intro again.
    controller.startSolo();
    scheduler.elapse(3000);
    expect(shell.phase, RoundPhase.roundPlay);
  });

  test('abandonMatch outside ROUND_PLAY is a no-op', () {
    controller.abandonMatch();
    expect(shell.phase, RoundPhase.lobby);
  });

  test('humanFinishMs_exposes_the_human_finish_tick_in_ms', () {
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);

    // Human finished at tick 1 (scripted): 1 / 60 Hz -> ~17 ms.
    expect(controller.humanFinishMs, 17);
  });

  test('humanFinishMs_is_null_when_the_human_never_finished', () {
    // No PlayerFinished events: everyone is ranked by progress only.
    final timeoutShell = ShellController();
    final timeoutScheduler = FakeSoloScheduler();
    final timeoutController = SoloMatchController(
      shell: timeoutShell,
      config: const SoloMatchConfig(matchSeed: 3),
      scheduler: timeoutScheduler.call,
      simulationFactory: (minigameId, mapSeed, roster) =>
          FakeSoloSim(minigameId: minigameId, roster: roster),
    );
    addTearDown(timeoutController.dispose);

    timeoutController.startSolo();
    timeoutScheduler.elapse(3000);
    final session = timeoutController.currentRound;
    expect(session, isNotNull, reason: 'round must be built on ROUND_PLAY');
    while (!session!.driver.isRoundOver) {
      session.driver.tick();
    }
    expect(timeoutShell.phase, RoundPhase.roundResults);

    expect(timeoutController.humanFinishMs, isNull);
  });

  test('humanFinishMs_resets_between_matches', () {
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(controller.humanFinishMs, 17);

    controller.playAgain();
    scheduler.elapse(3000);

    // Fresh match, fresh round: no finish recorded yet.
    expect(controller.humanFinishMs, isNull);
  });
}

List<RoundPhase> deduped(List<RoundPhase> phases) {
  final deduped = <RoundPhase>[];
  for (final phase in phases) {
    if (deduped.isEmpty || deduped.last != phase) {
      deduped.add(phase);
    }
  }
  return deduped;
}
