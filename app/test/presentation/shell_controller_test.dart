import 'package:app/shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

RoundResult _roundResult(int roundIndex, List<String> playerOrder) {
  final ranked = playerOrder.length;
  return RoundResult(
    roundIndex: roundIndex,
    minigameId: 'trap_race',
    placements: [
      for (var i = 0; i < playerOrder.length; i++)
        Placement(
          playerId: playerOrder[i],
          rank: i + 1,
          points: Points.forPlacements(ranked, i + 1),
        ),
    ],
  );
}

void main() {
  group('ShellController happy path', () {
    test('LOBBY -> ... -> PODIUM -> LOBBY notifies per transition', () {
      final controller = ShellController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.phase, RoundPhase.lobby);
      expect(controller.roundIndex, 0);
      expect(controller.latestRoundResult, isNull);
      expect(controller.matchResult, isNull);

      const players = ['a', 'b', 'c', 'd'];
      for (var round = 0; round < MatchRules.roundCount; round++) {
        // LOBBY (or ROUND_RESULTS) -> ROUND_INTRO.
        if (round == 0) {
          controller.startMatch();
        } else {
          controller.beginRound();
        }
        expect(controller.phase, RoundPhase.roundIntro);
        expect(controller.roundIndex, round);

        // ROUND_INTRO -> ROUND_PLAY.
        controller.startPlay();
        expect(controller.phase, RoundPhase.roundPlay);

        // ROUND_PLAY -> ROUND_RESULTS with a domain result.
        final result = _roundResult(round, players);
        controller.endRound(result);
        expect(controller.phase, RoundPhase.roundResults);
        expect(controller.latestRoundResult, same(result));
      }

      // ROUND_RESULTS -> PODIUM (match complete after 5 rounds).
      controller.toPodium();
      expect(controller.phase, RoundPhase.podium);

      // Final rankings come from the domain (Rankings.finalRanking).
      final rankings = controller.matchResult;
      expect(rankings, isNotNull);
      expect(
        rankings!.finalRankings.map((p) => p.playerId).toList(),
        players,
      );
      expect(rankings.finalRankings.first.points, 20); // 4pt * 5 rounds.
      expect(
        rankings.finalRankings.map((p) => p.rank).toList(),
        [1, 2, 3, 4],
      );

      // PODIUM -> LOBBY resets for a rematch.
      controller.toLobby();
      expect(controller.phase, RoundPhase.lobby);
      expect(controller.roundIndex, 0);
      expect(controller.latestRoundResult, isNull);
      expect(controller.matchResult, isNull);

      // 3 transitions per round * 5 rounds + toPodium + toLobby.
      expect(notifications, 17);
    });
  });

  group('ShellController invalid transitions', () {
    test('toPodium from LOBBY propagates InvalidTransitionException', () {
      final controller = ShellController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.toPodium, throwsA(isA<InvalidTransitionException>()));
      expect(controller.phase, RoundPhase.lobby);
      expect(notifications, 0);
    });

    test('startPlay from LOBBY propagates InvalidTransitionException', () {
      final controller = ShellController();
      expect(controller.startPlay, throwsA(isA<InvalidTransitionException>()));
      expect(controller.phase, RoundPhase.lobby);
    });

    test('startMatch from PODIUM propagates InvalidTransitionException', () {
      final controller = ShellController()
        ..startMatch()
        ..startPlay()
        ..endRound(_roundResult(0, ['a', 'b']))
        ..toPodium();
      expect(
        controller.startMatch,
        throwsA(isA<InvalidTransitionException>()),
      );
      expect(controller.phase, RoundPhase.podium);
    });
  });

  group('ShellController wrap-around rematch', () {
    test('second match after toLobby replays the full flow', () {
      final controller = ShellController()
        ..startMatch()
        ..startPlay()
        ..endRound(_roundResult(0, ['a', 'b']))
        ..toPodium()
        ..toLobby();
      expect(controller.phase, RoundPhase.lobby);
      expect(controller.roundIndex, 0);

      controller
        ..beginRound()
        ..startPlay()
        ..endRound(_roundResult(0, ['b', 'a']));
      expect(controller.phase, RoundPhase.roundResults);
      expect(controller.roundIndex, 1);
      expect(controller.latestRoundResult!.placements.first.playerId, 'b');
    });
  });
}
