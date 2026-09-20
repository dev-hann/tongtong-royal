// FINAL-variant suite for CourseMap.trapRaceFinal. Separate file
// (same subject, distinct variant) so the grandfathered prose-named
// course_map_test.dart stays untouched (testing doc § 10 carve-outs).
import 'package:app/game/course/course_map.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('CourseMap.trapRaceFinal', () {
    test('same_seed_produces_identical_final_course', () {
      final a = CourseMap.trapRaceFinal(42, 2);
      final b = CourseMap.trapRaceFinal(42, 2);

      expect(a, equals(b));
      expect(a.toJson(), equals(b.toJson()));
    });

    test('different_seed_jitters_hammer_pivots_and_wall_phases', () {
      final a = CourseMap.trapRaceFinal(7, 2);
      final b = CourseMap.trapRaceFinal(8, 2);

      expect(
        a.hammers.first.pivot.x,
        isNot(equals(b.hammers.first.pivot.x)),
      );
      expect(
        a.movingWalls.first.phase,
        isNot(equals(b.movingWalls.first.phase)),
      );
    });

    test('json_roundtrip_preserves_the_final_course', () {
      for (final seed in [0, 7, 42]) {
        final map = CourseMap.trapRaceFinal(seed);

        final restored = CourseMap.fromJson(map.toJson());

        expect(restored, equals(map), reason: 'seed $seed');
      }
    });

    test('json_roundtrip_of_standard_course_still_parses', () {
      final standard = CourseMap.trapRace(5);

      final restored = CourseMap.fromJson(standard.toJson());

      expect(restored, equals(standard));
      expect(restored.spawnPoints, isEmpty);
      expect(restored.movingWalls, isEmpty);
    });

    test('platform_lane_width_is_reduced_60_percent', () {
      final map = CourseMap.trapRaceFinal(3, 2);

      const standardLaneWidth = 6.0;
      const expected = standardLaneWidth * 0.4;
      expect(map.platforms, isNotEmpty);
      for (final platform in map.platforms) {
        expect(platform.width, closeTo(expected, 1e-9));
      }
    });

    test('gap_lane_widens_gaps_to_2_5m_within_seed_jitter', () {
      final map = CourseMap.trapRaceFinal(3, 2);

      final sorted = [...map.platforms]
        ..sort((a, b) => a.center.x.compareTo(b.center.x));
      // Epsilon 1e-6 m: contiguous platforms leave float dust in
      // the left/right comparison, real gaps are meters wide.
      const epsilon = 1e-6;
      final gaps = <double>[];
      for (var i = 0; i + 1 < sorted.length; i++) {
        final left = sorted[i].center.x + sorted[i].width / 2;
        final right = sorted[i + 1].center.x - sorted[i + 1].width / 2;
        if (right - left > epsilon) {
          gaps.add(right - left);
        }
      }

      expect(gaps, hasLength(2), reason: 'segment 2 carries two pit gaps');
      for (final gap in gaps) {
        expect(
          gap,
          closeTo(2.5, 0.2 + 1e-9),
          reason: 'schema jitters gap width by ±0.2 m',
        );
      }
    });

    test('hammer_speed_is_1_6_rad_s_exactly', () {
      final map = CourseMap.trapRaceFinal(3, 2);

      expect(map.hammers, hasLength(2));
      for (final hammer in map.hammers) {
        expect(hammer.angularSpeed, 1.6);
      }
    });

    test('no_checkpoints_in_the_final_variant', () {
      expect(CourseMap.trapRaceFinal(3, 2).checkpoints, isEmpty);
    });

    test('moving_walls_oscillate_1_5m_at_3s_period', () {
      final map = CourseMap.trapRaceFinal(3, 2);

      expect(map.movingWalls, hasLength(2));
      for (final wall in map.movingWalls) {
        expect(wall.amplitude, 1.5);
        expect(wall.period, 3);
        expect(
          wall.width,
          greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
        );
      }
    });

    test('finish_sits_beyond_every_hazard', () {
      final map = CourseMap.trapRaceFinal(3);

      final lastHammerX = map.hammers
          .map((h) => h.pivot.x)
          .reduce((a, b) => a > b ? a : b);
      final lastWallX = map.movingWalls
          .map((w) => w.center.x)
          .reduce((a, b) => a > b ? a : b);

      expect(map.finishLine.center.x, greaterThan(lastHammerX));
      expect(map.finishLine.center.x, greaterThan(lastWallX));
      expect(
        map.killY,
        lessThan(map.platforms.first.center.y + map.platforms.first.height / 2),
      );
    });

    test('spawn_slots_spread_distinct_and_on_start_platform', () {
      for (final starters in [2, 4]) {
        final map = CourseMap.trapRaceFinal(3, starters);

        expect(map.spawnPoints, hasLength(starters));
        final xs = map.spawnPoints.map((p) => p.x).toSet();
        expect(xs, hasLength(starters), reason: '$starters starters');
        final first = map.platforms.reduce(
          (a, b) => a.center.x < b.center.x ? a : b,
        );
        for (final spawn in map.spawnPoints) {
          expect(
            spawn.x,
            greaterThan(first.center.x - first.width / 2),
            reason: '$starters starters: spawn inside start platform',
          );
          expect(
            spawn.x,
            lessThan(first.center.x + first.width / 2),
            reason: '$starters starters: spawn inside start platform',
          );
          expect(
            spawn.y,
            closeTo(
              PlayerCharacter.heightMeters / 2 + 0.01,
              1e-9,
            ),
            reason: '$starters starters: spawn anchor height',
          );
        }
        // Spawns must be pairwise separated by at least one player
        // width so idle bodies never overlap-stack.
        final sortedXs = xs.toList()..sort();
        for (var i = 1; i < sortedXs.length; i++) {
          expect(
            sortedXs[i] - sortedXs[i - 1],
            greaterThanOrEqualTo(PlayerCharacter.widthMeters),
            reason: '$starters starters: adjacent slots',
          );
        }
      }
    });

    test('starters_out_of_2_to_4_range_throw', () {
      expect(() => CourseMap.trapRaceFinal(3, 1), throwsArgumentError);
      expect(() => CourseMap.trapRaceFinal(3, 5), throwsArgumentError);
    });

    test('effective_spawn_points_falls_back_to_spawn_point', () {
      final standard = CourseMap.trapRace(3);

      expect(standard.effectiveSpawnPoints, [standard.spawnPoint]);
    });

    test('course_is_runnable_hazard_gaps_exist', () {
      final map = CourseMap.trapRaceFinal(3, 2);

      // Every platform except the last has something ahead of it —
      // no dead-end stretches.
      expect(map.platforms.length, 9);
      expect(map.walls, hasLength(1));
      expect(map.hammers, hasLength(2));
      expect(map.movingWalls, hasLength(2));
    });
  });

  test('final_course_constants_live_in_map_data', () {
    // Guard against accidental geometry drift: total course length
    // stays within the segment-2-4 envelope (9 platforms of 2.4 m +
    // 2 gaps of ~2.5 m ~= 26.6 m).
    final map = CourseMap.trapRaceFinal(0, 2);
    final maxX = map.platforms
        .map((p) => p.center.x + p.width / 2)
        .reduce((a, b) => a > b ? a : b);
    expect(maxX, closeTo(9 * 2.4 + 2 * 2.5, 0.5));
    expect(map.finishLine.center.x, lessThan(maxX + 1));
    expect(Vector2(map.spawnPoint.x, map.spawnPoint.y).length, greaterThan(0));
  });
}
