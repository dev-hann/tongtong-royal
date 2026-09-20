import 'dart:math' as math;

import 'package:app/game/course/course_map.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('CourseMap.trapRace determinism', () {
    test('same_seed_produces_identical_course_data', () {
      final a = CourseMap.trapRace(42);
      final b = CourseMap.trapRace(42);

      expect(a, equals(b));
      expect(a.toJson(), equals(b.toJson()));
    });

    test('different_seed_jitters_the_hammer_positions', () {
      final a = CourseMap.trapRace(7).hammers.first.pivot;
      final b = CourseMap.trapRace(8).hammers.first.pivot;

      expect(a.x, isNot(equals(b.x)));
    });

    test('json_roundtrip_preserves_the_map', () {
      for (final seed in [0, 7, 42]) {
        final map = CourseMap.trapRace(seed);

        final restored = CourseMap.fromJson(map.toJson());

        expect(restored, equals(map), reason: 'seed $seed');
      }
    });
  });

  group('CourseMap.trapRace level design (trap-race.md)', () {
    test('runway_gives_a_flat_safe_run_before_the_first_pit_gap', () {
      final map = CourseMap.trapRace(3);
      final gaps = _pitGapsOf(map);
      final sorted = [...map.platforms]..sort(_comparePlatformX);

      // Segment 1: the runway — contiguous flat slabs from the
      // course origin, at least the promised ~12 m of safe start
      // (trap-race.md segment 1) before the gap lane opens.
      final firstGapStart = gaps.first.startX;
      final runway = sorted
          .where((p) => p.center.x + p.width / 2 <= firstGapStart + 1e-6)
          .toList();
      expect(
        runway.first.center.x - runway.first.width / 2,
        closeTo(0, 1e-9),
        reason: 'runway starts at the course origin',
      );
      expect(
        firstGapStart,
        greaterThanOrEqualTo(12),
        reason: 'at least ~12 m of flat runway before the first pit',
      );
      for (final slab in runway) {
        expect(_topY(slab), closeTo(0, 1e-9), reason: 'runway is flat');
      }
    });

    test('gap_lane_carries_two_pit_gaps_of_1_5m_and_2_0m', () {
      for (final seed in [0, 3, 42]) {
        final gaps = _pitGapsOf(CourseMap.trapRace(seed));

        expect(gaps, hasLength(2), reason: 'seed $seed: two pit gaps');
        expect(
          gaps[0].width,
          closeTo(1.5, 0.2 + 1e-9),
          reason: 'seed $seed: first gap 1.5 m ± the schema jitter',
        );
        expect(
          gaps[1].width,
          closeTo(2.0, 0.2 + 1e-9),
          reason: 'seed $seed: second gap 2.0 m ± the schema jitter',
        );
      }
    });

    test('hammer_alley_spans_two_hammers_at_1_2_rad_s', () {
      final map = CourseMap.trapRace(3);

      expect(map.hammers, hasLength(2));
      for (final hammer in map.hammers) {
        expect(
          hammer.angularSpeed,
          1.2,
          reason: 'standard-course hammer speed (trap-race.md segment 3)',
        );
      }
    });

    test('hammer_alley_phase_offsets_the_two_arms_by_half_a_turn', () {
      final map = CourseMap.trapRace(3);

      final offset = (map.hammers[1].initialAngle - map.hammers[0].initialAngle)
          .abs();
      expect(
        offset,
        closeTo(math.pi, 1e-9),
        reason: 'arms enter offset by half a revolution',
      );
    });

    test('hammer_alley_offers_an_elevated_safe_lane_1m_high', () {
      final map = CourseMap.trapRace(3);

      final elevated = map.platforms
          .where((p) => _topY(p) > 0.5 && _topY(p) < 1.5)
          .toList();
      expect(elevated, hasLength(1), reason: 'exactly one elevated lane');
      final lane = elevated.single;
      expect(
        _topY(lane),
        closeTo(1, 1e-9),
        reason: 'the safe lane is a 1 m platform (trap-race.md segment 3)',
      );
      // Safe = out of every hammer's sweep: a player standing on the
      // lane (body spanning [top, top + height]) never overlaps an
      // arm circle, counting the player half width and the arm half
      // thickness as horizontal clearance.
      for (final hammer in map.hammers) {
        final edgeClearance =
            (lane.center.x - hammer.pivot.x).abs() - lane.width / 2;
        final bodyTop = _topY(lane) + PlayerCharacter.heightMeters;
        final verticalGap = (bodyTop - hammer.pivot.y).abs();
        final reach = verticalGap >= hammer.radius
            ? 0.0
            : math.sqrt(
                hammer.radius * hammer.radius - verticalGap * verticalGap,
              );
        final needed =
            reach + PlayerCharacter.widthMeters / 2 + hammer.armThickness / 2;
        expect(
          edgeClearance,
          greaterThan(needed),
          reason: 'elevated lane stays outside the hammer sweep circle',
        );
      }
    });

    test('squeeze_gates_oscillate_1_5m_at_3s_period', () {
      final map = CourseMap.trapRace(3);

      expect(map.movingWalls, hasLength(2));
      for (final wall in map.movingWalls) {
        expect(wall.amplitude, 1.5, reason: 'amplitude pinned by the doc');
        expect(wall.period, 3, reason: 'period pinned 2026-09-19');
      }
    });

    test('squeeze_gates_clear_a_standing_player_when_fully_open', () {
      final map = CourseMap.trapRace(3);

      for (final wall in map.movingWalls) {
        final openBottom = wall.center.y + wall.amplitude - wall.height / 2;
        expect(
          openBottom,
          greaterThanOrEqualTo(PlayerCharacter.heightMeters),
          reason: 'fully open gate clears a 1.5 m player',
        );
      }
    });

    test('final_stretch_runs_10m_downhill_to_the_finish', () {
      final map = CourseMap.trapRace(3);
      final sorted = [...map.platforms]..sort(_comparePlatformX);
      final lastWallX = map.movingWalls
          .map((w) => w.center.x)
          .reduce((a, b) => a > b ? a : b);
      final stretch = sorted
          .skipWhile((p) => p.center.x - p.width / 2 <= lastWallX)
          .toList();

      // Segment 5: strictly descending platform tops over ~10 m,
      // finish sensor at the bottom.
      final tops = [for (final p in stretch) _topY(p)];
      for (var i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          lessThan(tops[i - 1]),
          reason: 'final stretch platform $i descends',
        );
      }
      expect(
        stretch.last.center.x +
            stretch.last.width / 2 -
            (stretch.first.center.x - stretch.first.width / 2),
        closeTo(10, 1.5),
        reason: 'final stretch spans ~10 m (trap-race.md segment 5)',
      );
      expect(
        map.finishLine.center.x,
        lessThan(stretch.last.center.x + stretch.last.width / 2),
        reason: 'finish sensor sits on the last platform',
      );
    });

    test('checkpoints_ascend_toward_the_finish', () {
      final map = CourseMap.trapRace(3);

      var previousX = map.spawnPoint.x;
      for (final checkpoint in map.checkpoints) {
        expect(checkpoint.x, greaterThan(previousX));
        previousX = checkpoint.x;
      }
      expect(map.finishLine.center.x, greaterThan(previousX));
      for (final platform in map.platforms) {
        expect(map.killY, lessThan(_topY(platform)));
      }
    });

    test('blueprint_counts_match_the_five_segment_program', () {
      final map = CourseMap.trapRace(3);

      // 2 runway + 3 gap-lane + 3 alley (2 ground + 1 elevated) +
      // 2 squeeze + 3 downhill slabs.
      expect(map.platforms, hasLength(13));
      expect(map.walls, hasLength(1));
      expect(map.hammers, hasLength(2));
      expect(map.movingWalls, hasLength(2));
      expect(map.checkpoints, hasLength(4));
      for (final wall in map.walls) {
        expect(
          wall.width,
          greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
        );
      }
    });

    test('spawn_point_sits_on_the_runway_surface', () {
      final map = CourseMap.trapRace(3);

      expect(map.spawnPoint.x, closeTo(3, 1e-9));
      expect(
        map.spawnPoint.y,
        closeTo(PlayerCharacter.heightMeters / 2 + 0.01, 1e-9),
        reason: 'half a player plus clearance above the surface',
      );
      expect(map.effectiveSpawnPoints, [map.spawnPoint]);
    });
  });
}

int _comparePlatformX(BoxSpec a, BoxSpec b) => a.center.x.compareTo(b.center.x);

double _topY(BoxSpec box) => box.center.y + box.height / 2;

/// The pit gaps between consecutive platforms, in course order
/// (ascending x), ignoring float dust between contiguous platforms.
List<({double startX, double width})> _pitGapsOf(CourseMap map) {
  final sorted = [...map.platforms]..sort(_comparePlatformX);
  const epsilon = 1e-6;
  final gaps = <({double startX, double width})>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final left = sorted[i].center.x + sorted[i].width / 2;
    final right = sorted[i + 1].center.x - sorted[i + 1].width / 2;
    if (right - left > epsilon) {
      gaps.add((startX: left, width: right - left));
    }
  }
  return gaps;
}
