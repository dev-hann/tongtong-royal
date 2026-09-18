import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

RoundResult _round(int index, List<Placement> placements) => RoundResult(
  roundIndex: index,
  minigameId: 'mg$index',
  placements: placements,
);

void main() {
  test('no_tie_orders_by_cumulative_points_desc', () {
    final rounds = [
      _round(1, const [
        Placement(playerId: 'a', rank: 1, points: 4),
        Placement(playerId: 'b', rank: 2, points: 3),
        Placement(playerId: 'c', rank: 3, points: 2),
        Placement(playerId: 'd', rank: 4, points: 1),
      ]),
      _round(2, const [
        Placement(playerId: 'b', rank: 1, points: 4),
        Placement(playerId: 'c', rank: 2, points: 3),
        Placement(playerId: 'a', rank: 3, points: 2),
        Placement(playerId: 'd', rank: 4, points: 1),
      ]),
    ];

    final result = Rankings.finalRanking(rounds, const {});

    // Totals: a=6, b=7, c=5, d=2.
    expect(result.finalRankings.map((p) => p.playerId), ['b', 'a', 'c', 'd']);
    expect(result.finalRankings.map((p) => p.points), [7, 6, 5, 2]);
    expect(result.finalRankings.map((p) => p.rank), [1, 2, 3, 4]);
  });

  test('gdd_2_1_tie_resolved_by_last_round_placement', () {
    final rounds = [
      _round(1, const [
        Placement(playerId: 'a', rank: 1, points: 3),
        Placement(playerId: 'b', rank: 2, points: 2),
        Placement(playerId: 'c', rank: 3, points: 1),
      ]),
      _round(2, const [
        Placement(playerId: 'b', rank: 1, points: 3),
        Placement(playerId: 'a', rank: 2, points: 2),
        Placement(playerId: 'c', rank: 3, points: 1),
      ]),
    ];
    // Totals: a=5, b=5, c=2. Last round: b rank 1 beats a rank 2.

    final result = Rankings.finalRanking(rounds, const {});

    expect(result.finalRankings.map((p) => p.playerId), ['b', 'a', 'c']);
    expect(result.finalRankings.map((p) => p.rank), [1, 2, 3]);
  });

  test('gdd_2_1_tie_resolved_by_earlier_round_when_last_equal', () {
    final rounds = [
      _round(1, const [
        Placement(playerId: 'c', rank: 1, points: 3),
        Placement(playerId: 'b', rank: 2, points: 2),
        Placement(playerId: 'a', rank: 3, points: 1),
      ]),
      _round(2, const [
        Placement(playerId: 'a', rank: 1, points: 3),
        Placement(playerId: 'b', rank: 2, points: 2),
        Placement(playerId: 'c', rank: 3, points: 1),
      ]),
      _round(3, const [
        Placement(playerId: 'a', rank: 1, points: 3),
        Placement(playerId: 'b', rank: 1, points: 3),
        Placement(playerId: 'c', rank: 3, points: 1),
      ]),
    ];
    // Totals: a=7, b=7, c=5. Round 3: a and b share rank 1 (GDD 7.6),
    // so the tie falls back to round 2: a rank 1 beats b rank 2.

    final result = Rankings.finalRanking(rounds, const {});

    expect(result.finalRankings.map((p) => p.playerId), ['a', 'b', 'c']);
    expect(result.finalRankings.map((p) => p.rank), [1, 2, 3]);
  });

  test('gdd_2_1_full_tie_shares_rank_next_rank_skipped', () {
    final rounds = [
      _round(1, const [
        Placement(playerId: 'a', rank: 1, points: 4),
        Placement(playerId: 'b', rank: 1, points: 4),
        Placement(playerId: 'c', rank: 3, points: 2),
      ]),
      _round(2, const [
        Placement(playerId: 'b', rank: 1, points: 4),
        Placement(playerId: 'a', rank: 1, points: 4),
        Placement(playerId: 'c', rank: 3, points: 2),
      ]),
    ];
    // a = b = 8 with identical placement lists -> share 1st; c is 3rd.

    final result = Rankings.finalRanking(rounds, const {});

    expect(
      result.finalRankings.take(2).map((p) => p.playerId),
      containsAll(['a', 'b']),
    );
    expect(result.finalRankings.take(2).map((p) => p.rank), everyElement(1));
    expect(result.finalRankings[2].playerId, 'c');
    expect(result.finalRankings[2].rank, 3);
    expect(result.finalRankings[2].points, 4);
  });

  test('gdd_7_2_forfeited_player_excluded_from_rankings', () {
    final rounds = [
      _round(1, const [
        Placement(playerId: 'a', rank: 1, points: 4),
        Placement(playerId: 'b', rank: 2, points: 3),
        Placement(playerId: 'leaver', rank: 3, points: 2),
      ]),
      _round(2, const [
        Placement(playerId: 'b', rank: 1, points: 4),
        Placement(playerId: 'a', rank: 2, points: 3),
      ]),
    ];

    final result = Rankings.finalRanking(rounds, {'leaver'});

    expect(
      result.finalRankings.map((p) => p.playerId),
      isNot(contains('leaver')),
    );
    expect(result.finalRankings.map((p) => p.playerId), ['b', 'a']);
  });

  test('player_missing_one_round_ranked_below_tied_player', () {
    // a is absent from round 2; absent = worst placement in that round.
    // Totals: a=3, b=1+2=3, c=2+1=3. All tied on points.
    final rounds = [
      _round(1, const [
        Placement(playerId: 'a', rank: 1, points: 3),
        Placement(playerId: 'c', rank: 2, points: 2),
        Placement(playerId: 'b', rank: 3, points: 1),
      ]),
      _round(2, const [
        Placement(playerId: 'b', rank: 1, points: 2),
        Placement(playerId: 'c', rank: 2, points: 1),
      ]),
    ];

    final result = Rankings.finalRanking(rounds, const {});

    expect(result.finalRankings.map((p) => p.playerId), ['b', 'c', 'a']);
  });

  test('empty_rounds_produce_empty_rankings', () {
    final result = Rankings.finalRanking(const [], const {});
    expect(result.finalRankings, isEmpty);
  });

  test('all_players_forfeited_produce_empty_rankings', () {
    final rounds = [
      _round(1, const [Placement(playerId: 'a', rank: 1, points: 4)]),
    ];

    final result = Rankings.finalRanking(rounds, {'a'});

    expect(result.finalRankings, isEmpty);
  });
}
