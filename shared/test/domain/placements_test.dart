import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  test('gdd_7_6_two_share_first_in_4p_next_finisher_is_third', () {
    final placements = Placements.fromRankGroups(
      [
        ['p1', 'p2'],
        ['p3'],
        ['p4'],
      ],
      4,
    );

    expect(placements, hasLength(4));
    expect(placements[0], const Placement(playerId: 'p1', rank: 1, points: 4));
    expect(placements[1], const Placement(playerId: 'p2', rank: 1, points: 4));
    expect(placements[2], const Placement(playerId: 'p3', rank: 3, points: 2));
    expect(placements[3], const Placement(playerId: 'p4', rank: 4, points: 1));
  });

  test('gdd_7_5_two_survivors_share_first_in_4p_both_get_4pt', () {
    final placements = Placements.fromRankGroups(
      [
        ['p1', 'p2'],
      ],
      4,
    );

    expect(placements, hasLength(2));
    expect(
      placements,
      everyElement(
        isA<Placement>()
            .having((p) => p.rank, 'rank', 1)
            .having((p) => p.points, 'points', 4),
      ),
    );
  });

  test('gdd_7_7_all_eliminated_same_tick_share_that_rank_group', () {
    final placements = Placements.fromRankGroups(
      [
        ['p1'],
        ['p2', 'p3', 'p4'],
      ],
      4,
    );

    expect(placements[0].rank, 1);
    expect(placements[0].points, 4);
    expect(placements[1].rank, 2);
    expect(placements[1].points, 3);
    expect(placements[2], const Placement(playerId: 'p3', rank: 2, points: 3));
    expect(placements[3], const Placement(playerId: 'p4', rank: 2, points: 3));
  });

  test('three_share_second_in_4p_all_get_3pt_next_rank_is_5', () {
    final placements = Placements.fromRankGroups(
      [
        ['p4'],
        ['p1', 'p2', 'p3'],
      ],
      4,
    );

    expect(placements[0].rank, 1);
    expect(placements[0].points, 4);
    for (final p in placements.skip(1)) {
      expect(p.rank, 2);
      expect(p.points, 3);
    }
  });

  test('no_sharing_plain_ranks', () {
    final placements = Placements.fromRankGroups(
      [
        ['p2'],
        ['p1'],
        ['p3'],
      ],
      3,
    );

    expect(placements[0], const Placement(playerId: 'p2', rank: 1, points: 3));
    expect(placements[1], const Placement(playerId: 'p1', rank: 2, points: 2));
    expect(placements[2], const Placement(playerId: 'p3', rank: 3, points: 1));
  });

  test('leaver_scaled_round_points_use_players_in_round', () {
    final placements = Placements.fromRankGroups(
      [
        ['p1'],
        ['p2'],
      ],
      4,
    );

    expect(placements[0].points, 4);
    expect(placements[1].points, 3);
  });

  test('empty_rank_groups_produce_no_placements', () {
    expect(Placements.fromRankGroups(const [], 4), isEmpty);
  });

  test('empty_group_throws_argument_error', () {
    expect(
      () => Placements.fromRankGroups(
        [
          ['p1'],
          [],
        ],
        4,
      ),
      throwsArgumentError,
    );
  });

  test('more_ranked_players_than_round_players_throws_argument_error', () {
    expect(
      () => Placements.fromRankGroups(
        [
          ['p1'],
          ['p2'],
        ],
        1,
      ),
      throwsArgumentError,
    );
  });
}
