import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const game = HammerDodge();

  RoundEvents round({
    List<RoundEvent> events = const [],
    int quota = 2,
    Set<PlayerId> roster = const {'a', 'b', 'c'},
  }) => RoundEvents(
    roundIndex: 1,
    events: events,
    quota: quota,
    roster: roster,
  );

  group('v1 placements path (revived from git 6ef70f3)', () {
    test('id_is_hammer_dodge', () {
      expect(game.id, 'hammer_dodge');
    });

    test('spec_metadata_matches_game_doc', () {
      final spec = game.spec;

      expect(spec.name, 'Hammer Dodge');
      expect(spec.oneLineRule, 'Last two standing qualify');
      expect(spec.timeoutMs, 60_000);
    });

    test('elimination_order_reversed_placements', () {
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

      expect(result.minigameId, 'hammer_dodge');
      expect(result.placements.map((p) => p.playerId), ['d', 'b', 'a', 'c']);
      expect(result.placements.map((p) => p.rank), [1, 2, 3, 4]);
    });

    test('same_tick_eliminations_form_shared_rank_group', () {
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
    });

    test('duplicate_elimination_events_first_one_wins', () {
      final result = game.resolve(
        const RoundEvents(
          roundIndex: 0,
          events: [
            PlayerEliminated(tick: 10, playerId: 'a'),
            PlayerEliminated(tick: 50, playerId: 'a'),
          ],
        ),
        const HammerDodgeInput(roster: {'a', 'b'}),
      );

      expect(result.placements.map((p) => p.playerId), ['b', 'a']);
      expect(result.placements.map((p) => p.rank), [1, 2]);
    });

    test('zero_eliminations_all_players_share_rank_1', () {
      final result = game.resolve(
        const RoundEvents(roundIndex: 0),
        const HammerDodgeInput(roster: {'a', 'b'}),
      );

      expect(result.placements.map((p) => p.playerId), ['a', 'b']);
      expect(result.placements.map((p) => p.rank), [1, 1]);
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

      expect(result.minigameId, 'hammer_dodge');
      expect(result.placements.map((p) => p.playerId), ['b', 'a']);
    });
  });

  group('qualification path (GDD v2)', () {
    test('hammer_quota_last_two_alive', () {
      final result = game.resolveQualification(round(events: [
        const PlayerEliminated(tick: 10, playerId: 'a'),
      ]));

      expect(result.qualified, equals(['b', 'c']));
      expect(result.eliminated, equals(['a']));
      expect(result.isFinal, isFalse);
      expect(result.champions, isEmpty);
    });

    test('gdd_7_1_single_event_crossing_victims_qualify', () {
      final result = game.resolveQualification(round(events: [
        const PlayerEliminated(tick: 10, playerId: 'b'),
        const PlayerEliminated(tick: 10, playerId: 'c'),
      ]));

      // One event took 3 alive to 1: the victims also qualify.
      expect(result.qualified, equals(['a', 'b', 'c']));
      expect(result.eliminated, isEmpty);
    });

    test('hammer_timeout_all_survivors_qualify', () {
      final result = game.resolveQualification(round());

      expect(result.qualified, equals(['a', 'b', 'c']));
      expect(result.eliminated, isEmpty);
    });

    test('hammer_timeout_four_alive_degenerate_all_qualify', () {
      final result = game.resolveQualification(
        round(roster: {'a', 'b', 'c', 'd'}),
      );

      expect(result.qualified, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });

    test('hammer_timeout_after_partial_eliminations', () {
      final result = game.resolveQualification(
        round(
          roster: {'a', 'b', 'c', 'd'},
          events: [const PlayerEliminated(tick: 5, playerId: 'a')],
        ),
      );

      // 3 alive > quota 2 at timeout: survival IS qualification.
      expect(result.qualified, equals(['b', 'c', 'd']));
      expect(result.eliminated, equals(['a']));
    });

    test('hammer_all_eliminated_same_tick_all_qualify', () {
      final result = game.resolveQualification(round(events: [
        const PlayerEliminated(tick: 10, playerId: 'a'),
        const PlayerEliminated(tick: 10, playerId: 'b'),
        const PlayerEliminated(tick: 10, playerId: 'c'),
      ]));

      expect(result.qualified, equals(['a', 'b', 'c']));
      expect(result.eliminated, isEmpty);
    });

    test('hammer_duplicate_elimination_idempotent', () {
      final result = game.resolveQualification(round(events: [
        const PlayerEliminated(tick: 10, playerId: 'a'),
        const PlayerEliminated(tick: 20, playerId: 'b'),
        const PlayerEliminated(tick: 50, playerId: 'a'),
      ]));

      // The round ended at tick 10 (2 alive); everything after is
      // relay noise and the duplicate never re-eliminates.
      expect(result.qualified, equals(['b', 'c']));
      expect(result.eliminated, equals(['a']));
    });

    test('hammer_multi_elim_same_tick_not_crossing_eliminates', () {
      final result = game.resolveQualification(
        round(
          roster: {'a', 'b', 'c', 'd'},
          events: [
            const PlayerEliminated(tick: 10, playerId: 'a'),
            const PlayerEliminated(tick: 10, playerId: 'b'),
          ],
        ),
      );

      // 4 -> 2 lands exactly on the quota: no crossing, no sharing.
      expect(result.qualified, equals(['c', 'd']));
      expect(result.eliminated, equals(['a', 'b']));
    });

    test('hammer_quota_equals_field_all_qualify', () {
      final result = game.resolveQualification(
        round(roster: {'a', 'b'}),
      );

      expect(result.qualified, equals(['a', 'b']));
      expect(result.eliminated, isEmpty);
    });

    test('hammer_resolve_qualification_through_contract', () {
      const QualificationGame asContract = HammerDodge();

      final result = asContract.resolveQualification(round(events: [
        const PlayerEliminated(tick: 10, playerId: 'a'),
      ]));

      expect(result.qualified, equals(['b', 'c']));
    });

    test('hammer_qualification_requires_quota', () {
      expect(
        () => game.resolveQualification(
          const RoundEvents(
            roundIndex: 1,
            events: [PlayerEliminated(tick: 10, playerId: 'a')],
            roster: {'a', 'b'},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('hammer_qualification_quota_below_one_throws', () {
      expect(
        () => game.resolveQualification(round(quota: 0)),
        throwsArgumentError,
        reason: 'quota 0 would eliminate everyone silently',
      );
      expect(
        () => game.resolveQualification(round(quota: -1)),
        throwsArgumentError,
      );
    });

    test('hammer_qualification_empty_field_throws', () {
      expect(
        () => game.resolveQualification(
          const RoundEvents(roundIndex: 1, quota: 2),
        ),
        throwsArgumentError,
        reason: 'no roster and no event players: no field',
      );
    });

    test('hammer_qualification_rejects_final_mode', () {
      expect(
        () => game.resolveQualification(
          const RoundEvents(
            roundIndex: 2,
            quota: 1,
            isFinal: true,
            roster: {'a', 'b'},
            events: [PlayerEliminated(tick: 1, playerId: 'a')],
          ),
        ),
        throwsArgumentError,
        reason: 'hammer_dodge only runs as ROUND 2 (game doc § Identity)',
      );
    });

    test('hammer_qualification_rejects_foreign_input', () {
      expect(
        () => game.resolveQualification(round(), 'bogus'),
        throwsArgumentError,
      );
    });
  });
}
