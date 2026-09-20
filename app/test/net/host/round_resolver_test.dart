import 'package:app/net/host/round_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('resolveQualificationRound', () {
    test('trap_race_final_finish_resolves_the_champion', () {
      const events = RoundEvents(
        roundIndex: 2,
        events: [
          PlayerEliminated(tick: 100, playerId: 'p2'),
          PlayerFinished(tick: 300, playerId: 'p1'),
        ],
        quota: 1,
        isFinal: true,
        roster: {'p1', 'p2'},
      );

      final result = resolveQualificationRound(
        const TrapRace(),
        events,
        const RoundData(roster: {'p1', 'p2'}),
      );

      expect(result.isFinal, isTrue);
      expect(result.champions, ['p1']);
      expect(result.qualified, ['p1']);
      expect(result.eliminated, ['p2']);
    });

    test('trap_race_round_one_fills_the_quota_by_finish_order', () {
      const events = RoundEvents(
        roundIndex: 0,
        events: [
          PlayerFinished(tick: 10, playerId: 'p1'),
          PlayerFinished(tick: 20, playerId: 'p2'),
        ],
        quota: 3,
        roster: {'p1', 'p2', 'p3', 'p4'},
      );
      const data = RoundData(
        roster: {'p1', 'p2', 'p3', 'p4'},
        progressSamples: [
          ProgressSample(tick: 30, playerId: 'p3', distance: 5),
          ProgressSample(tick: 30, playerId: 'p4', distance: 2),
        ],
      );

      final result = resolveQualificationRound(const TrapRace(), events, data);

      expect(result.isFinal, isFalse);
      expect(result.qualified, ['p1', 'p2', 'p3']);
      expect(result.eliminated, ['p4']);
    });

    test('hammer_dodge_resolves_survivors_plus_crossing_victims', () {
      // 3 alive -> 1 in one tick crosses the quota of 2: the
      // crossing event's victims also qualify (GDD § 7.1).
      const events = RoundEvents(
        roundIndex: 1,
        events: [
          PlayerEliminated(tick: 50, playerId: 'p2'),
          PlayerEliminated(tick: 50, playerId: 'p3'),
        ],
        quota: 2,
        roster: {'p1', 'p2', 'p3'},
      );

      final result = resolveQualificationRound(
        const HammerDodge(),
        events,
        const RoundData(roster: {'p1', 'p2', 'p3'}),
      );

      expect(result.isFinal, isFalse);
      expect(result.qualified, containsAll(['p1', 'p2', 'p3']));
      expect(result.eliminated, isEmpty);
    });

    test('unknown_game_throws_argument_error', () {
      expect(
        () => resolveQualificationRound(
          const _UnknownGame(),
          const RoundEvents(roundIndex: 0, quota: 1, roster: {'p1'}),
          const RoundData(roster: {'p1'}),
        ),
        throwsArgumentError,
      );
    });
  });

  group('resolveRound (v1 placements path unchanged)', () {
    test('trap_race_resolves_placements_from_finishes', () {
      const events = RoundEvents(
        roundIndex: 0,
        events: [PlayerFinished(tick: 10, playerId: 'p1')],
        roster: {'p1', 'p2'},
      );

      final result = resolveRound(
        const TrapRace(),
        events,
        const RoundData(roster: {'p1', 'p2'}),
      );

      expect(result.minigameId, 'trap_race');
      expect(result.placements.first.playerId, 'p1');
    });
  });
}

final class _UnknownGame implements MiniGame {
  const _UnknownGame();

  @override
  MiniGameId get id => 'unknown_game';

  @override
  RoundResult resolve(RoundEvents events) {
    throw UnimplementedError();
  }

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Unknown',
    oneLineRule: 'n/a',
    timeoutMs: 1000,
  );
}
