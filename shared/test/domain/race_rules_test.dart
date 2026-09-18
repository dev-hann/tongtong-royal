import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  test('all_finish_ordered_by_finish_tick_asc', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'b', finished: true, finishTick: 20, progressDistance: 1),
      (id: 'c', finished: true, finishTick: 30, progressDistance: 1),
      (id: 'a', finished: true, finishTick: 10, progressDistance: 1),
    ]);

    expect(groups, [
      ['a'],
      ['b'],
      ['c'],
    ]);
  });

  test('gdd_7_4_none_finish_ranked_by_progress_distance_desc', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'a', finished: false, finishTick: 0, progressDistance: 12.5),
      (id: 'b', finished: false, finishTick: 0, progressDistance: 40.0),
      (id: 'c', finished: false, finishTick: 0, progressDistance: 25.0),
    ]);

    expect(groups, [
      ['b'],
      ['c'],
      ['a'],
    ]);
  });

  test('gdd_7_4_mixed_finishers_ranked_above_unfinished', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'slow', finished: false, finishTick: 0, progressDistance: 99.0),
      (id: 'fast', finished: true, finishTick: 500, progressDistance: 10.0),
      (id: 'mid', finished: false, finishTick: 0, progressDistance: 50.0),
    ]);

    expect(groups, [
      ['fast'],
      ['slow'],
      ['mid'],
    ]);
  });

  test('gdd_7_6_same_tick_finishers_share_rank_group', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'late', finished: true, finishTick: 30, progressDistance: 1),
      (id: 'a', finished: true, finishTick: 10, progressDistance: 1),
      (id: 'b', finished: true, finishTick: 10, progressDistance: 1),
    ]);

    expect(groups, [
      ['a', 'b'],
      ['late'],
    ]);
  });

  test('gdd_7_6_same_tick_group_next_rank_is_skipped', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'a', finished: true, finishTick: 10, progressDistance: 1),
      (id: 'b', finished: true, finishTick: 10, progressDistance: 1),
      (id: 'c', finished: true, finishTick: 20, progressDistance: 1),
    ]);

    final placements = Placements.fromRankGroups(groups, 3);

    expect(placements[0].rank, 1);
    expect(placements[1].rank, 1);
    expect(placements[2].rank, 3);
  });

  test('same_progress_distance_unfinished_share_group', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'a', finished: false, finishTick: 0, progressDistance: 10.0),
      (id: 'b', finished: false, finishTick: 0, progressDistance: 30.0),
      (id: 'c', finished: false, finishTick: 0, progressDistance: 10.0),
    ]);

    expect(groups, [
      ['b'],
      ['a', 'c'],
    ]);
  });

  test('same_tick_same_distance_two_groups_stay_distinct', () {
    final groups = RaceRules.rankOnTimeout(const [
      (id: 'u1', finished: false, finishTick: 0, progressDistance: 10.0),
      (id: 'f1', finished: true, finishTick: 10, progressDistance: 10.0),
    ]);

    expect(groups, [
      ['f1'],
      ['u1'],
    ]);
  });

  test('empty_input_produces_no_rank_groups', () {
    expect(RaceRules.rankOnTimeout(const []), isEmpty);
  });

  test('duplicate_player_id_throws_argument_error', () {
    expect(
      () => RaceRules.rankOnTimeout(const [
        (id: 'a', finished: true, finishTick: 1, progressDistance: 1),
        (id: 'a', finished: false, finishTick: 0, progressDistance: 2),
      ]),
      throwsArgumentError,
    );
  });
}
