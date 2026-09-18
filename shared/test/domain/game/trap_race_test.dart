import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const game = TrapRace();

  test('id_is_trap_race', () {
    expect(game.id, 'trap_race');
  });

  test('spec_metadata_matches_gdd', () {
    final spec = game.spec;

    expect(spec.name, 'Trap Race');
    expect(spec.oneLineRule, 'First to the finish line');
    expect(spec.timeoutMs, 90_000);
  });

  test('all_finish_ranked_by_finish_tick_ascending', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 1,
        events: [
          PlayerFinished(tick: 30, playerId: 'c'),
          PlayerFinished(tick: 10, playerId: 'a'),
          PlayerFinished(tick: 20, playerId: 'b'),
        ],
      ),
    );

    expect(result.roundIndex, 1);
    expect(result.minigameId, 'trap_race');
    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3]);
    expect(result.placements.map((p) => p.points), [3, 2, 1]);
  });

  test('gdd_7_6_same_tick_finishers_share_rank_and_next_rank_skipped', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          PlayerFinished(tick: 10, playerId: 'a'),
          PlayerFinished(tick: 10, playerId: 'b'),
          PlayerFinished(tick: 20, playerId: 'c'),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 1, 3]);
    expect(result.placements.map((p) => p.points), [3, 3, 1]);
  });

  test('gdd_7_4_none_finish_ranked_by_last_progress_sample', () {
    final result = game.resolve(
      const RoundEvents(roundIndex: 0),
      const TrapRaceInput(
        samples: [
          ProgressSample(tick: 1, playerId: 'b', distance: 40),
          ProgressSample(tick: 5, playerId: 'a', distance: 12.5),
          ProgressSample(tick: 6, playerId: 'c', distance: 25),
          ProgressSample(tick: 8, playerId: 'a', distance: 15),
        ],
      ),
    );

    // 'a' has two samples; the last one (15.0) must win over 12.5.
    expect(result.placements.map((p) => p.playerId), ['b', 'c', 'a']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3]);
    expect(result.placements.map((p) => p.points), [3, 2, 1]);
  });

  test('gdd_7_4_finishers_ranked_above_non_finishers', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [PlayerFinished(tick: 100, playerId: 'a')],
      ),
      const TrapRaceInput(
        samples: [
          ProgressSample(tick: 90, playerId: 'b', distance: 20),
          ProgressSample(tick: 90, playerId: 'c', distance: 50),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'c', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3]);
    expect(result.placements.map((p) => p.points), [3, 2, 1]);
  });

  test('players_without_events_rank_last_by_zero_progress', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [PlayerFinished(tick: 10, playerId: 'a')],
      ),
      const TrapRaceInput(
        roster: {'a', 'b', 'c', 'd'},
        samples: [ProgressSample(tick: 90, playerId: 'b', distance: 30)],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c', 'd']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3, 3]);
    expect(result.placements.map((p) => p.points), [4, 3, 2, 2]);
  });

  test('resolve_works_through_minigame_interface_without_input', () {
    const MiniGame asInterface = TrapRace();

    final result = asInterface.resolve(
      const RoundEvents(
        roundIndex: 3,
        events: [PlayerFinished(tick: 7, playerId: 'a')],
      ),
    );

    expect(result.roundIndex, 3);
    expect(result.minigameId, 'trap_race');
    expect(result.placements.single.playerId, 'a');
    expect(result.placements.single.rank, 1);
  });
}
