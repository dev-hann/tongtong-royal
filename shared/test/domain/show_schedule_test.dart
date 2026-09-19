import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const schedule = ShowSchedule.standard;

  test('show_schedule_slots_and_quotas', () {
    final slots = schedule.slots;

    expect(slots, hasLength(3));
    expect(slots[0].roundIndex, 1);
    expect(slots[0].gameId, 'trap_race');
    expect(slots[0].quota, 3);
    expect(slots[0].isFinal, isFalse);
    expect(slots[1].roundIndex, 2);
    expect(slots[1].gameId, 'hammer_dodge');
    expect(slots[1].quota, 2);
    expect(slots[1].isFinal, isFalse);
    expect(slots[2].roundIndex, 3);
    expect(slots[2].gameId, 'trap_race');
    expect(slots[2].quota, 1);
    expect(slots[2].isFinal, isTrue);
  });

  test('show_schedule_slot_for_returns_matching_slot', () {
    expect(schedule.slotFor(2).gameId, 'hammer_dodge');
    expect(schedule.slotFor(3).isFinal, isTrue);
  });

  test('show_schedule_slot_for_out_of_range_throws', () {
    expect(() => schedule.slotFor(0), throwsArgumentError);
    expect(() => schedule.slotFor(4), throwsArgumentError);
  });

  test('show_schedule_starter_round_one_is_fixed_field', () {
    expect(schedule.starterCountFor(1), 4);
  });

  test('show_schedule_starter_round_one_rejects_previous_verdict', () {
    expect(
      () => schedule.starterCountFor(1, previousQualified: const ['a']),
      throwsArgumentError,
      reason: 'round 1 starts from the fixed 4-seat show field',
    );
  });

  test('show_schedule_starter_cascade', () {
    // GDD § 4 note: every spec tolerates one extra starter.
    const fourWayTieR1 = QualificationResult(
      qualified: ['a', 'b', 'c', 'd'],
      eliminated: [],
      isFinal: false,
    );

    expect(
      schedule.starterCountFor(
        2,
        previousQualified: fourWayTieR1.qualified,
      ),
      4,
      reason: 'R2 accepts 4 starters when R1 over-qualifies',
    );

    const fourAliveR2Timeout = QualificationResult(
      qualified: ['a', 'b', 'c', 'd'],
      eliminated: [],
      isFinal: false,
    );

    expect(
      schedule.starterCountFor(
        3,
        previousQualified: fourAliveR2Timeout.qualified,
      ),
      4,
      reason: 'FINAL accepts 2-4 starters (GDD § 4 table)',
    );
  });

  test('show_schedule_starter_count_out_of_tolerance_throws', () {
    expect(
      () => schedule.starterCountFor(2, previousQualified: const ['a']),
      throwsArgumentError,
      reason: 'R2 cannot receive fewer than 3 starters',
    );
    expect(
      () => schedule.starterCountFor(
        2,
        previousQualified: const ['a', 'b', 'c', 'd', 'e'],
      ),
      throwsArgumentError,
      reason: '5 starters exceeds the tolerated cascade of one',
    );
    expect(
      () => schedule.starterCountFor(3, previousQualified: const ['a']),
      throwsArgumentError,
      reason: 'FINAL cannot start with one runner',
    );
  });

  test('show_schedule_seed_stream_deterministic', () {
    final first = ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 2);
    final second = ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 2);

    expect(first, second);
  });

  test('show_schedule_seed_stream_differs_per_round', () {
    final r1 = ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 1);
    final r2 = ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 2);
    final r3 = ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 3);

    expect(r1, isNot(equals(r2)));
    expect(r2, isNot(equals(r3)));
    expect(r1, isNot(equals(r3)));
  });

  test('show_schedule_seed_stream_not_addition', () {
    // A literal showSeed + roundIndex stream collides across shows:
    // (42, 2) and (43, 1) must NOT derive the same course.
    expect(
      ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 2),
      isNot(equals(ShowSchedule.mapSeedFor(showSeed: 43, roundIndex: 1))),
    );
    expect(
      ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 1),
      isNot(equals(ShowSchedule.mapSeedFor(showSeed: 43, roundIndex: 2))),
    );
    expect(
      ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 3),
      isNot(equals(ShowSchedule.mapSeedFor(showSeed: 44, roundIndex: 1))),
    );
  });

  test('show_schedule_seed_stream_round_out_of_range_throws', () {
    expect(
      () => ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 0),
      throwsArgumentError,
    );
    expect(
      () => ShowSchedule.mapSeedFor(showSeed: 42, roundIndex: 4),
      throwsArgumentError,
    );
  });
}
