import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'fake_solo_scheduler.dart';
import 'fake_solo_sim.dart';

/// Fake sim that emits a full ranking script on its first tick so
/// every round resolves deterministically: the human wins every
/// archetype.
final class _ScriptedSoloSim extends FakeSoloSim {
  _ScriptedSoloSim({
    required this.minigameOrder,
    required super.minigameId,
    required super.roster,
  }) : super(completeAfterTicks: 3);

  /// Roster order used by the scripts (best first).
  final List<PlayerId> minigameOrder;

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      _emitScript();
    }
    super.tickInputs(inputs);
  }

  void _emitScript() {
    switch (minigameId) {
      case 'trap_race':
        emit(const PlayerFinished(tick: 1, playerId: 'solo-player'));
        emit(const PlayerFinished(tick: 2, playerId: 'bot-1'));
        emit(const PlayerFinished(tick: 3, playerId: 'bot-2'));
        emit(const PlayerFinished(tick: 4, playerId: 'bot-3'));
      case 'hammer_dodge':
        emit(const PlayerEliminated(tick: 1, playerId: 'bot-3'));
        emit(const PlayerEliminated(tick: 2, playerId: 'bot-2'));
        emit(const PlayerEliminated(tick: 3, playerId: 'bot-1'));
      case 'king_of_the_hill':
        emit(const HoldTimeSample(playerId: 'solo-player', seconds: 9));
        emit(const HoldTimeSample(playerId: 'bot-1', seconds: 6));
        emit(const HoldTimeSample(playerId: 'bot-2', seconds: 3));
        emit(const HoldTimeSample(playerId: 'bot-3', seconds: 1));
      default:
        fail('script missing for $minigameId');
    }
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
        final sim = _ScriptedSoloSim(
          minigameOrder: roster.toList(),
          minigameId: minigameId,
          roster: roster,
        );
        createdSims.add(sim);
        return sim;
      },
    );
    addTearDown(controller.dispose);
  });

  /// Steps one round to completion through the session driver.
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

  test('full match: five rounds then podium with domain standings', () {
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

    for (var round = 0; round < 5; round++) {
      scheduler.elapse(3000); // intro countdown
      expect(shell.phase, RoundPhase.roundPlay);
      expect(
        controller.introName,
        const MinigameRegistry()
            .byId(controller.rounds[round].minigameId)
            .spec
            .name,
      );
      playRound();
      expect(shell.phase, RoundPhase.roundResults);
      scheduler.elapse(6000); // results auto-advance
    }

    expect(shell.phase, RoundPhase.podium);
    expect(results, hasLength(5));
    for (var round = 0; round < 5; round++) {
      expect(results[round].roundIndex, round);
      // 4 players ranked: points 4/3/2/1 (GDD § 2), human first in
      // every script.
      expect(results[round].placements, hasLength(4));
      expect(results[round].placements.first.playerId, 'solo-player');
      expect(results[round].placements.map((p) => p.points).toList(), [
        4,
        3,
        2,
        1,
      ]);
    }

    final rankings = shell.matchResult!.finalRankings;
    expect(rankings.first.playerId, 'solo-player');
    expect(rankings.first.points, 20);
    expect(rankings.map((p) => p.playerId).toSet(), {
      'solo-player',
      'bot-1',
      'bot-2',
      'bot-3',
    });

    // Deduped phase sequence: intro/play/results x5 then podium.
    final deduped = <RoundPhase>[];
    for (final phase in phases) {
      if (deduped.isEmpty || deduped.last != phase) {
        deduped.add(phase);
      }
    }
    expect(deduped, [
      RoundPhase.lobby,
      for (var i = 0; i < 5; i++) ...[
        RoundPhase.roundIntro,
        RoundPhase.roundPlay,
        RoundPhase.roundResults,
      ],
      RoundPhase.podium,
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

  test('results auto-advance fires after six seconds', () {
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);

    scheduler.elapse(5999);
    expect(shell.phase, RoundPhase.roundResults);

    scheduler.elapse(1);
    expect(shell.phase, RoundPhase.roundIntro);
    expect(shell.roundIndex, 1);
  });

  test('rematch replans with fresh seeds and restarts from the lobby', () {
    controller.startSolo();
    for (var round = 0; round < 5; round++) {
      scheduler.elapse(3000);
      playRound();
      scheduler.elapse(6000);
    }
    expect(shell.phase, RoundPhase.podium);
    final firstSeeds = controller.rounds.map((r) => r.mapSeed).toList();

    controller.rematch();

    expect(shell.phase, RoundPhase.lobby);
    expect(shell.roundIndex, 0);
    final secondSeeds = controller.rounds.map((r) => r.mapSeed).toList();
    expect(secondSeeds, isNot(equals(firstSeeds)));

    // And the rematch runs another full match.
    controller.startSolo();
    scheduler.elapse(3000);
    playRound();
    expect(shell.phase, RoundPhase.roundResults);
  });
}
