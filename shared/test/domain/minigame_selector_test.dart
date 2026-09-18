import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const pool = ['trap_race', 'hammer_dodge', 'king_of_the_hill'];

  test('gdd_6_five_rounds_from_three_games_correct_length', () {
    final plan = MinigameSelector.planMatch(5, pool, 42);

    expect(plan, hasLength(5));
  });

  test('gdd_6_no_immediate_repeat_between_cycles', () {
    final plan = MinigameSelector.planMatch(5, pool, 42);

    for (var i = 1; i < plan.length; i++) {
      expect(plan[i], isNot(plan[i - 1]), reason: 'rounds $i-1 and $i');
    }
  });

  test('gdd_6_all_games_appear_in_a_five_round_plan', () {
    final plan = MinigameSelector.planMatch(5, pool, 42);

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
    final a = MinigameSelector.planMatch(5, pool, 123);
    final b = MinigameSelector.planMatch(5, pool, 123);

    expect(a, equals(b));
  });

  test('different_seeds_produce_different_plans', () {
    final a = MinigameSelector.planMatch(5, pool, 1);
    final b = MinigameSelector.planMatch(5, pool, 2);

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
      () => MinigameSelector.planMatch(5, const [], 1),
      throwsArgumentError,
    );
  });

  test('duplicate_games_in_pool_throw_argument_error', () {
    expect(
      () => MinigameSelector.planMatch(5, ['a', 'a', 'b'], 1),
      throwsArgumentError,
    );
  });
}
