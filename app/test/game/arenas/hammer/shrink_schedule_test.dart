import 'package:app/game/arenas/hammer/shrink_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShrinkSchedule.radiusAt', () {
    final schedule = ShrinkSchedule(
      startSeconds: 30,
      durationSeconds: 15,
      endRadius: 4.5,
      tierCount: 5,
    );

    test('radiusAt_holds_start_radius_before_shrink_starts', () {
      expect(schedule.radiusAt(7, 0), 7);
      expect(schedule.radiusAt(7, 29.999), 7);
      expect(schedule.radiusAt(7, 30), 7);
    });

    test('radiusAt_lerps_linearly_during_shrink', () {
      expect(schedule.radiusAt(7, 37.5), closeTo(5.75, 1e-9));
      expect(schedule.radiusAt(7, 33.75), closeTo(6.375, 1e-9));
    });

    test('radiusAt_settles_at_end_radius_after_shrink', () {
      expect(schedule.radiusAt(7, 45), 4.5);
      expect(schedule.radiusAt(7, 120), 4.5);
    });

    test('radiusAt_rejects_non_finite_seconds', () {
      expect(
        () => schedule.radiusAt(7, double.nan),
        throwsArgumentError,
      );
    });
  });

  group('ShrinkSchedule.tierRadii', () {
    test('tierRadii_descends_from_start_to_end_radius', () {
      final schedule = ShrinkSchedule(
        startSeconds: 30,
        durationSeconds: 15,
        endRadius: 4.5,
        tierCount: 5,
      );

      expect(
        schedule.tierRadii(7),
        [7, 6.375, 5.75, 5.125, 4.5],
      );
    });

    test('tierRadii_smallest_two_tier_schedule_spans_the_range', () {
      final schedule = ShrinkSchedule(
        startSeconds: 30,
        durationSeconds: 15,
        endRadius: 4.5,
        tierCount: 2,
      );

      expect(schedule.tierRadii(7), [7, 4.5]);
    });
  });

  group('ShrinkSchedule validation', () {
    test('tierRadii_rejects_start_radius_at_or_below_end_radius', () {
      final schedule = ShrinkSchedule(
        startSeconds: 30,
        durationSeconds: 15,
        endRadius: 4.5,
        tierCount: 5,
      );

      expect(() => schedule.tierRadii(4.5), throwsArgumentError);
      expect(() => schedule.tierRadii(3), throwsArgumentError);
    });

    test('constructor_rejects_non_positive_duration', () {
      expect(
        () => ShrinkSchedule(
          startSeconds: 30,
          durationSeconds: 0,
          endRadius: 4.5,
          tierCount: 5,
        ),
        throwsArgumentError,
      );
    });

    test('constructor_rejects_tier_count_below_two', () {
      expect(
        () => ShrinkSchedule(
          startSeconds: 30,
          durationSeconds: 15,
          endRadius: 4.5,
          tierCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test('constructor_rejects_negative_start', () {
      expect(
        () => ShrinkSchedule(
          startSeconds: -1,
          durationSeconds: 15,
          endRadius: 4.5,
          tierCount: 5,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ShrinkSchedule JSON', () {
    test('json_roundtrip_preserves_the_schedule', () {
      final schedule = ShrinkSchedule(
        startSeconds: 30,
        durationSeconds: 15,
        endRadius: 4.5,
        tierCount: 5,
      );

      final restored = ShrinkSchedule.fromJson(schedule.toJson());

      expect(restored.startSeconds, 30);
      expect(restored.durationSeconds, 15);
      expect(restored.endRadius, 4.5);
      expect(restored.tierCount, 5);
      expect(restored.toJson(), schedule.toJson());
    });

    test('fromJson_rejects_missing_fields', () {
      expect(
        () => ShrinkSchedule.fromJson(const {'startSeconds': 30}),
        throwsFormatException,
      );
    });
  });
}
