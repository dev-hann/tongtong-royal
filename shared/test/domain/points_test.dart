import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  group('Points.forPlacements', () {
    test('gdd_2_two_player_round_awards_2_and_1', () {
      expect(Points.forPlacements(2, 1), 2);
      expect(Points.forPlacements(2, 2), 1);
    });

    test('gdd_2_three_player_round_awards_3_2_1', () {
      expect(Points.forPlacements(3, 1), 3);
      expect(Points.forPlacements(3, 2), 2);
      expect(Points.forPlacements(3, 3), 1);
    });

    test('gdd_2_four_player_round_awards_4_3_2_1', () {
      expect(Points.forPlacements(4, 1), 4);
      expect(Points.forPlacements(4, 2), 3);
      expect(Points.forPlacements(4, 3), 2);
      expect(Points.forPlacements(4, 4), 1);
    });

    test('last_place_boundary_rank_equals_player_count', () {
      expect(Points.forPlacements(2, 2), 1);
      expect(Points.forPlacements(3, 3), 1);
      expect(Points.forPlacements(4, 4), 1);
    });

    test('rank_zero_throws_argument_error', () {
      expect(() => Points.forPlacements(4, 0), throwsArgumentError);
    });

    test('rank_above_player_count_throws_argument_error', () {
      expect(() => Points.forPlacements(4, 5), throwsArgumentError);
    });

    test('ranked_player_count_below_one_throws_argument_error', () {
      expect(() => Points.forPlacements(0, 1), throwsArgumentError);
    });
  });

  group('Points.forSharedRank', () {
    test('gdd_7_6_shared_first_in_four_player_round_scores_four', () {
      expect(Points.forSharedRank(4, 1), 4);
    });

    test('shared_rank_scores_that_rank_points_in_full_round', () {
      expect(Points.forSharedRank(4, 2), 3);
      expect(Points.forSharedRank(4, 3), 2);
      expect(Points.forSharedRank(3, 1), 3);
      expect(Points.forSharedRank(2, 1), 2);
    });

    test('gdd_7_5_two_survivors_share_first_both_get_first_place_points', () {
      expect(Points.forSharedRank(4, 1), 4);
      expect(Points.forSharedRank(2, 1), 2);
    });

    test('shared_rank_out_of_range_throws_argument_error', () {
      expect(() => Points.forSharedRank(4, 0), throwsArgumentError);
      expect(() => Points.forSharedRank(4, 5), throwsArgumentError);
    });
  });
}
