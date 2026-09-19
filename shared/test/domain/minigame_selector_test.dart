import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const pool = ['trap_race', 'hammer_dodge'];

  test('gdd_6_three_rounds_from_two_games_correct_length', () {
    final plan = MinigameSelector.planMatch(3, pool, 42);

    expect(plan, hasLength(3));
  });

  test('gdd_6_two_game_pool_alternates', () {
    // GDD § 6: with 2 games and 3 rounds the no-repeat constraint
    // forces strict alternation: A, B, A or B, A, B.
    for (final seed in [0, 1, 2, 3, 42, 7, 123]) {
      final plan = MinigameSelector.planMatch(3, pool, seed);

      expect(plan, hasLength(3), reason: 'seed $seed');
      expect(plan[0], isNot(plan[1]), reason: 'seed $seed');
      expect(plan[1], isNot(plan[2]), reason: 'seed $seed');
      expect(plan[0], plan[2],
          reason: 'seed $seed: third round returns to the opener');
    }
  });

  test('gdd_6_no_immediate_repeat_between_cycles', () {
    final plan = MinigameSelector.planMatch(7, pool, 42);

    for (var i = 1; i < plan.length; i++) {
      expect(plan[i], isNot(plan[i - 1]), reason: 'rounds $i-1 and $i');
    }
  });

  test('gdd_6_all_games_appear_in_a_three_round_plan', () {
    final plan = MinigameSelector.planMatch(3, pool, 42);

    expect(plan.toSet(), containsAll(pool));
  });

  test('gdd_6_constraint_holds_across_multiple_reshuffles', () {
    final plan = MinigameSelector.planMatch(11, pool, 7);

    expect(plan, hasLength(11));
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i], isNot(plan[i - 1]), reason: 'rounds $i-1 and $i');
    }
    expect(plan.toSet(), containsAll(pool));
  });

  test('deterministic_same_seed_same_plan', () {
    final a = MinigameSelector.planMatch(3, pool, 123);
    final b = MinigameSelector.planMatch(3, pool, 123);

    expect(a, equals(b));
  });

  test('different_seeds_produce_different_plans', () {
    final a = MinigameSelector.planMatch(3, pool, 1);
    final b = MinigameSelector.planMatch(3, pool, 2);

    expect(a, isNot(equals(b)));
  });

  test('plan_only_contains_games_from_the_pool', () {
    final plan = MinigameSelector.planMatch(11, pool, 9);

    expect(pool, containsAll(plan.toSet()));
  });

  test('single_game_pool_repeats_without_constraint', () {
    final plan = MinigameSelector.planMatch(3, ['solo'], 1);

    expect(plan, ['solo', 'solo', 'solo']);
  });

  test('rounds_zero_returns_empty_plan', () {
    expect(MinigameSelector.planMatch(0, pool, 1), isEmpty);
  });

  test('empty_pool_throws_argument_error', () {
    expect(
      () => MinigameSelector.planMatch(3, const [], 1),
      throwsArgumentError,
    );
  });

  test('duplicate_games_in_pool_throw_argument_error', () {
    expect(
      () => MinigameSelector.planMatch(3, ['a', 'a', 'b'], 1),
      throwsArgumentError,
    );
  });
}
