import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  test('Placement exposes playerId, rank, points with value equality', () {
    const a = Placement(playerId: 'p1', rank: 1, points: 4);
    const b = Placement(playerId: 'p1', rank: 1, points: 4);
    const c = Placement(playerId: 'p1', rank: 2, points: 3);

    expect(a.playerId, 'p1');
    expect(a.rank, 1);
    expect(a.points, 4);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });

  test('RoundResult exposes roundIndex, minigameId and placements', () {
    const result = RoundResult(
      roundIndex: 3,
      minigameId: 'trap_race',
      placements: [Placement(playerId: 'p1', rank: 1, points: 4)],
    );

    expect(result.roundIndex, 3);
    expect(result.minigameId, 'trap_race');
    expect(result.placements, hasLength(1));
    expect(result.placements.single.playerId, 'p1');
  });

  test('MatchResult exposes finalRankings', () {
    const match = MatchResult(
      finalRankings: [Placement(playerId: 'p1', rank: 1, points: 15)],
    );

    expect(match.finalRankings.single.rank, 1);
    expect(match.finalRankings.single.points, 15);
  });

  test('gdd_2_match_constants_match_the_gdd', () {
    expect(MatchRules.roundCount, 1);
    expect(MatchRules.minPlayers, 2);
    expect(MatchRules.maxPlayers, 4);
  });
}
