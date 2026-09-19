// Subject: TrapRace.resolveQualification (GDD v2 qualification era).
// Separate from trap_race_test.dart (v1 placements path) because the
// qualification contract is a separate unit under test (law 10.1.4).
import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const game = TrapRace();

  RoundEvents r1({
    List<RoundEvent> events = const [],
    int quota = 3,
    Set<PlayerId> roster = const {'a', 'b', 'c', 'd'},
  }) => RoundEvents(
    roundIndex: 0,
    events: events,
    quota: quota,
    roster: roster,
  );

  RoundEvents finalRound({
    List<RoundEvent> events = const [],
    Set<PlayerId> roster = const {'a', 'b'},
    List<ProgressSample> samples = const [],
  }) => RoundEvents(
    roundIndex: 2,
    events: events,
    quota: 1,
    isFinal: true,
    roster: roster,
  );

  group('r1 mode', () {
    test('trap_race_r1_finish_order_fills_quota', () {
      final result = game.resolveQualification(
        r1(events: [
          const PlayerFinished(tick: 30, playerId: 'c'),
          const PlayerFinished(tick: 10, playerId: 'a'),
          const PlayerFinished(tick: 20, playerId: 'b'),
        ]),
      );

      expect(result.qualified, equals(['a', 'b', 'c']));
      expect(result.eliminated, equals(['d']));
      expect(result.isFinal, isFalse);
      expect(result.champions, isEmpty);
    });

    test('gdd_7_1_same_tick_finishers_each_hold_slot', () {
      final result = game.resolveQualification(
        r1(events: [
          const PlayerFinished(tick: 10, playerId: 'a'),
          const PlayerFinished(tick: 20, playerId: 'b'),
          const PlayerFinished(tick: 30, playerId: 'c'),
          const PlayerFinished(tick: 30, playerId: 'd'),
        ]),
      );

      // c and d tie for the last slot: both hold one, so the next
      // round field grows to 4 (GDD § 7.1).
      expect(result.qualified, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });

    test('gdd_7_1_quota_never_shrinks_chain', () {
      final result = game.resolveQualification(
        r1(events: [
          const PlayerFinished(tick: 10, playerId: 'a'),
          const PlayerFinished(tick: 10, playerId: 'b'),
          const PlayerFinished(tick: 10, playerId: 'c'),
          const PlayerFinished(tick: 10, playerId: 'd'),
        ]),
      );

      expect(result.qualified, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });

    test('trap_race_r1_timeout_progress_fills_quota', () {
      final result = game.resolveQualification(
        r1(),
        const TrapRaceInput(
          samples: [
            ProgressSample(tick: 90, playerId: 'a', distance: 50),
            ProgressSample(tick: 90, playerId: 'b', distance: 40),
            ProgressSample(tick: 90, playerId: 'c', distance: 30),
            ProgressSample(tick: 90, playerId: 'd', distance: 20),
          ],
        ),
      );

      expect(result.qualified, equals(['a', 'b', 'c']));
      expect(result.eliminated, equals(['d']));
    });

    test('trap_race_r1_timeout_progress_tie_shares_boundary_slot', () {
      final result = game.resolveQualification(
        r1(),
        const TrapRaceInput(
          samples: [
            ProgressSample(tick: 90, playerId: 'a', distance: 50),
            ProgressSample(tick: 90, playerId: 'b', distance: 40),
            ProgressSample(tick: 90, playerId: 'c', distance: 30),
            ProgressSample(tick: 90, playerId: 'd', distance: 30),
          ],
        ),
      );

      expect(result.qualified, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });

    test('trap_race_r1_falls_respawn_not_eliminate', () {
      final result = game.resolveQualification(
        r1(events: [
          const PlayerFell(tick: 5, playerId: 'a'),
          const PlayerFinished(tick: 20, playerId: 'b'),
          const PlayerFinished(tick: 30, playerId: 'c'),
          const PlayerFinished(tick: 50, playerId: 'a'),
        ]),
      );

      expect(result.qualified, equals(['b', 'c', 'a']));
      expect(result.eliminated, equals(['d']));
    });

    test('trap_race_r1_quota_equals_field_all_qualify', () {
      final result = game.resolveQualification(
        r1(
          quota: 4,
          events: [
            const PlayerFinished(tick: 10, playerId: 'a'),
            const PlayerFinished(tick: 20, playerId: 'b'),
            const PlayerFinished(tick: 30, playerId: 'c'),
            const PlayerFinished(tick: 40, playerId: 'd'),
          ],
        ),
      );

      expect(result.qualified, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });
  });

  group('final mode', () {
    test('trap_race_final_finisher_is_champion', () {
      final result = game.resolveQualification(
        finalRound(events: [
          const PlayerFinished(tick: 42, playerId: 'a'),
        ]),
      );

      expect(result.isFinal, isTrue);
      expect(result.champions, equals(['a']));
      expect(result.qualified, equals(['a']));
      expect(result.eliminated, equals(['b']));
    });

    test('trap_race_final_survival_crown', () {
      final result = game.resolveQualification(
        finalRound(events: [
          const PlayerEliminated(tick: 30, playerId: 'b'),
        ]),
      );

      expect(result.champions, equals(['a']));
      expect(result.qualified, equals(['a']));
      expect(result.eliminated, equals(['b']));
    });

    test('trap_race_final_fall_signal_counts_as_elimination', () {
      final result = game.resolveQualification(
        finalRound(events: [
          const PlayerFell(tick: 30, playerId: 'b'),
        ]),
      );

      expect(result.champions, equals(['a']));
      expect(result.eliminated, equals(['b']));
    });

    test('gdd_7_2_shared_crown_two_champions', () {
      final result = game.resolveQualification(
        finalRound(events: [
          const PlayerEliminated(tick: 50, playerId: 'a'),
          const PlayerEliminated(tick: 50, playerId: 'b'),
        ]),
      );

      expect(result.champions, equals(['a', 'b']));
      expect(result.qualified, equals(['a', 'b']));
      expect(result.eliminated, isEmpty);
    });

    test('gdd_7_2_shared_crown_capped_at_field', () {
      final result = game.resolveQualification(
        finalRound(
          roster: {'a', 'b', 'c', 'd'},
          events: [
            const PlayerEliminated(tick: 60, playerId: 'a'),
            const PlayerEliminated(tick: 60, playerId: 'b'),
            const PlayerEliminated(tick: 60, playerId: 'c'),
            const PlayerEliminated(tick: 60, playerId: 'd'),
          ],
        ),
      );

      expect(result.champions, hasLength(4));
      expect(result.champions, equals(['a', 'b', 'c', 'd']));
      expect(result.eliminated, isEmpty);
    });

    test('trap_race_final_timeout_progress_leader_crown', () {
      final result = game.resolveQualification(
        finalRound(),
        const TrapRaceInput(
          samples: [
            ProgressSample(tick: 60, playerId: 'a', distance: 60),
            ProgressSample(tick: 60, playerId: 'b', distance: 50),
          ],
        ),
      );

      expect(result.champions, equals(['a']));
      expect(result.qualified, equals(['a']));
      expect(result.eliminated, equals(['b']));
    });

    test('trap_race_final_timeout_exact_progress_tie_shares_crown', () {
      final result = game.resolveQualification(
        finalRound(),
        const TrapRaceInput(
          samples: [
            ProgressSample(tick: 60, playerId: 'a', distance: 60),
            ProgressSample(tick: 60, playerId: 'b', distance: 60),
          ],
        ),
      );

      expect(result.champions, equals(['a', 'b']));
      expect(result.eliminated, isEmpty);
    });

    test('trap_race_final_same_tick_finish_beats_fall', () {
      final result = game.resolveQualification(
        finalRound(
          roster: {'a', 'b', 'c'},
          events: [
            const PlayerFell(tick: 40, playerId: 'c'),
            const PlayerFinished(tick: 50, playerId: 'a'),
            const PlayerFell(tick: 50, playerId: 'b'),
          ],
        ),
      );

      expect(result.champions, equals(['a']));
      expect(result.eliminated, equals(['c', 'b']));
    });

    test('trap_race_final_multi_fall_one_survivor_champion', () {
      final result = game.resolveQualification(
        finalRound(
          roster: {'a', 'b', 'c'},
          events: [
            const PlayerEliminated(tick: 30, playerId: 'b'),
            const PlayerEliminated(tick: 30, playerId: 'c'),
          ],
        ),
      );

      expect(result.champions, equals(['a']));
      expect(result.eliminated, equals(['b', 'c']));
    });
  });

  group('contract', () {
    test('trap_race_resolve_qualification_through_contract', () {
      const QualificationGame asContract = TrapRace();

      final result = asContract.resolveQualification(
        finalRound(events: [
          const PlayerFinished(tick: 7, playerId: 'a'),
        ]),
      );

      expect(result.champions, equals(['a']));
    });

    test('trap_race_qualification_quota_missing_throws', () {
      expect(
        () => game.resolveQualification(
          const RoundEvents(
            roundIndex: 0,
            events: [PlayerFinished(tick: 10, playerId: 'a')],
            roster: {'a', 'b'},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('trap_race_qualification_quota_below_one_throws', () {
      expect(
        () => game.resolveQualification(r1(quota: 0)),
        throwsArgumentError,
        reason: 'quota 0 would eliminate everyone silently',
      );
      expect(
        () => game.resolveQualification(r1(quota: -1)),
        throwsArgumentError,
      );
    });

    test('trap_race_qualification_empty_round_throws', () {
      expect(
        () => game.resolveQualification(r1()),
        throwsArgumentError,
        reason: 'no events and no samples: the round never ran',
      );
    });

    test('trap_race_qualification_empty_field_throws', () {
      expect(
        () => game.resolveQualification(
          const RoundEvents(roundIndex: 0, quota: 3),
        ),
        throwsArgumentError,
        reason: 'no roster and no event players: no field',
      );
    });

    test('trap_race_qualification_rejects_foreign_input', () {
      expect(
        () => game.resolveQualification(r1(), 'bogus'),
        throwsArgumentError,
      );
    });
  });
}
