import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const game = KingOfTheHill();

  test('id_is_king_of_the_hill', () {
    expect(game.id, 'king_of_the_hill');
  });

  test('spec_metadata_matches_gdd', () {
    final spec = game.spec;

    expect(spec.name, 'King of the Hill');
    expect(spec.oneLineRule, 'Hold the crown the longest');
    expect(spec.timeoutMs, 75_000);
  });

  test('gdd_4_3_ranked_by_last_hold_time_sample_descending', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 2,
        events: [
          HoldTimeSample(playerId: 'a', seconds: 4),
          HoldTimeSample(playerId: 'b', seconds: 9.5),
          HoldTimeSample(playerId: 'c', seconds: 2),
          // 'a' sampled twice: the later sample (5.5) must win over 4.
          HoldTimeSample(playerId: 'a', seconds: 5.5),
        ],
      ),
    );

    expect(result.roundIndex, 2);
    expect(result.minigameId, 'king_of_the_hill');
    expect(result.placements.map((p) => p.playerId), ['b', 'a', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 2, 3]);
    expect(result.placements.map((p) => p.points), [3, 2, 1]);
  });

  test('equal_hold_times_share_rank_and_next_rank_skipped', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          HoldTimeSample(playerId: 'a', seconds: 7),
          HoldTimeSample(playerId: 'b', seconds: 3),
          HoldTimeSample(playerId: 'c', seconds: 7),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'c', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 1, 3]);
    expect(result.placements.map((p) => p.points), [3, 3, 1]);
  });

  test('zero_hold_time_players_share_last_rank', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          HoldTimeSample(playerId: 'a', seconds: 12),
          HoldTimeSample(playerId: 'b', seconds: 0),
          HoldTimeSample(playerId: 'c', seconds: 0),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c']);
    expect(result.placements.map((p) => p.rank), [1, 2, 2]);
    // Shared rank scores the points of the shared rank itself
    // (GDD § 7.6): rank 2 of 3 players is worth 2.
    expect(result.placements.map((p) => p.points), [3, 2, 2]);
  });

  test('roster_player_without_samples_ranks_last_with_zero', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [HoldTimeSample(playerId: 'a', seconds: 6)],
      ),
      const KingOfTheHillInput(roster: {'a', 'b', 'd'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'd']);
    expect(result.placements.map((p) => p.rank), [1, 2, 2]);
    expect(result.placements.map((p) => p.points), [3, 2, 2]);
  });

  test('two_player_round_awards_2_and_1_points', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 4,
        events: [
          HoldTimeSample(playerId: 'x', seconds: 1),
          HoldTimeSample(playerId: 'y', seconds: 8),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['y', 'x']);
    expect(result.placements.map((p) => p.rank), [1, 2]);
    expect(result.placements.map((p) => p.points), [2, 1]);
  });

  test('mixed_four_player_round_points', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          HoldTimeSample(playerId: 'a', seconds: 20),
          HoldTimeSample(playerId: 'b', seconds: 20),
          HoldTimeSample(playerId: 'c', seconds: 0.5),
          HoldTimeSample(playerId: 'd', seconds: 0),
        ],
      ),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b', 'c', 'd']);
    expect(result.placements.map((p) => p.rank), [1, 1, 3, 4]);
    expect(result.placements.map((p) => p.points), [4, 4, 2, 1]);
  });

  test('empty_events_rank_every_roster_player_shared_first', () {
    final result = game.resolve(
      const RoundEvents(roundIndex: 0),
      const KingOfTheHillInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 1]);
    expect(result.placements.map((p) => p.points), [2, 2]);
  });

  test('fall_events_do_not_affect_ranking', () {
    final result = game.resolve(
      const RoundEvents(
        roundIndex: 0,
        events: [
          HoldTimeSample(playerId: 'a', seconds: 3),
          PlayerFell(tick: 10, playerId: 'a'),
          PlayerFell(tick: 20, playerId: 'b'),
        ],
      ),
      const KingOfTheHillInput(roster: {'a', 'b'}),
    );

    expect(result.placements.map((p) => p.playerId), ['a', 'b']);
    expect(result.placements.map((p) => p.rank), [1, 2]);
    expect(result.placements.map((p) => p.points), [2, 1]);
  });

  test('resolve_works_through_minigame_interface_without_input', () {
    const MiniGame asInterface = KingOfTheHill();

    final result = asInterface.resolve(
      const RoundEvents(
        roundIndex: 1,
        events: [HoldTimeSample(playerId: 'a', seconds: 2.5)],
      ),
    );

    expect(result.roundIndex, 1);
    expect(result.minigameId, 'king_of_the_hill');
    expect(result.placements.single.playerId, 'a');
    expect(result.placements.single.rank, 1);
  });
}
