import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const game = HammerDodge();

  test('id_is_hammer_dodge', () {
    expect(game.id, 'hammer_dodge');
  });

  test('spec_metadata_matches_gdd', () {
    final spec = game.spec;

    expect(spec.name, 'Hammer Dodge');
    expect(spec.oneLineRule, 'Last one standing wins');
    expect(spec.timeoutMs, 60_000);
  });

  test('full_elimination_order_reversed_first_eliminated_last', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          PlayerEliminated(tick: 5, playerId: 'c'),
          PlayerEliminated(tick: 10, playerId: 'a'),
          PlayerEliminated(tick: 20, playerId: 'b'),
        ],
      ),
      const HammerDodgeInput(roster: {'a', 'b', 'c', 'd'}),
    );

    expect(result.roundIndex, 0);
    expect(result.minigameId, 'hammer_dodge');
    expect(result.placements.map((p) => p.playerId), ['d', 'b', 'a', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3, 4]);
    expect(result.placements.map((p) => p.points), [4, 3, 2, 1]);
  });

  test('gdd_7_5_survivor_timeout_shares_best_rank', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 2,
        events: [
          PlayerEliminated(tick: 10, playerId: 'a'),
          PlayerEliminated(tick: 20, playerId: 'b'),
        ],
      ),
      const HammerDodgeInput(roster: {'a', 'b', 'c', 'd'}),
    );

    // Both survivors share 1st with full points; the skipped rank 2
    // is irrelevant (nobody stands between them and elimination
    // order, GDD § 7.5).
    expect(result.placements.map((p) => p.playerId), ['c', 'd', 'b', 'a']);
    expect(result.placements.map((p) => p.rank), [1, 1, 3, 4]);
    expect(result.placements.map((p) => p.points), [4, 4, 2, 1]);
  });

  test('gdd_7_7_same_tick_eliminations_form_shared_rank_group', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          PlayerEliminated(tick: 10, playerId: 'a'),
          PlayerEliminated(tick: 10, playerId: 'b'),
          PlayerEliminated(tick: 20, playerId: 'c'),
        ],
      ),
      const HammerDodgeInput(roster: {'a', 'b', 'c', 'd'}),
    );

    expect(result.placements.map((p) => p.playerId), ['d', 'c', 'a', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3, 3]);
    expect(result.placements.map((p) => p.points), [4, 3, 2, 2]);
  });

  test('gdd_7_7_all_eliminated_same_tick_share_top_group', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 1,
        events: [
          PlayerEliminated(tick: 30, playerId: 'a'),
          PlayerEliminated(tick: 30, playerId: 'b'),
          PlayerEliminated(tick: 30, playerId: 'c'),
        ],
      ),
      const HammerDodgeInput(roster: {'a', 'b', 'c'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 1, 1]);
    expect(result.placements.map((p) => p.points), [3, 3, 3]);
  });

  test('zero_eliminations_all_players_share_rank_1', () {
    final result = game.resolve(
      const RoundEvents(roundIndex: 0),
      const HammerDodgeInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 1]);
    expect(result.placements.map((p) => p.points), [2, 2]);
  });

  test('two_player_round_last_standing_wins', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 3,
        events: [PlayerEliminated(tick: 10, playerId: 'a')],
      ),
      const HammerDodgeInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['b', 'a']);
    expect(result.placements.map((p) => p.rank), [1, 2]);
    expect(result.placements.map((p) => p.points), [2, 1]);
  });

  test('duplicate_elimination_events_first_one_wins', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          PlayerEliminated(tick: 10, playerId: 'a'),
          PlayerEliminated(tick: 20, playerId: 'b'),
          PlayerEliminated(tick: 50, playerId: 'a'),
        ],
      ),
      const HammerDodgeInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['b', 'a']);
    expect(result.placements.map((p) => p.rank), [1, 2]);
    expect(result.placements.map((p) => p.points), [2, 1]);
  });

  test('non_elimination_events_do_not_eliminate', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [PlayerFell(tick: 5, playerId: 'a')],
      ),
      const HammerDodgeInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 1]);
    expect(result.placements.map((p) => p.points), [2, 2]);
  });

  test('resolve_works_through_minigame_interface_without_input', () {
    const MiniGame asInterface = HammerDodge();

    final result = asInterface.resolve(
      const RoundEvents(
        roundIndex: 1,
        events: [
          PlayerEliminated(tick: 7, playerId: 'a'),
          PlayerFell(tick: 9, playerId: 'b'),
        ],
      ),
    );

    expect(result.roundIndex, 1);
    expect(result.minigameId, 'hammer_dodge');
    expect(result.placements.map((p) => p.playerId), ['b', 'a']);
    expect(result.placements.map((p) => p.rank), [1, 2]);
    expect(result.placements.map((p) => p.points), [2, 1]);
  });
}
