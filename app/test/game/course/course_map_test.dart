import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('CourseMap.trapRace', () {
    test('same seed produces identical course data', () {
      final a = CourseMap.trapRace(42);
      final b = CourseMap.trapRace(42);

      expect(a, equals(b));
      expect(a.toJson(), equals(b.toJson()));
    });

    test('different seed jitters the hammer position', () {
      final a = CourseMap.trapRace(7).hammers.single.pivot;
      final b = CourseMap.trapRace(8).hammers.single.pivot;

      expect(a.x, isNot(equals(b.x)));
    });

    test('JSON roundtrip preserves the map', () {
      for (final seed in [0, 7, 42]) {
        final map = CourseMap.trapRace(seed);

        final restored = CourseMap.fromJson(map.toJson());

        expect(restored, equals(map), reason: 'seed $seed');
      }
    });

    test('factory produces a small but complete course', () {
      final map = CourseMap.trapRace(3);

      expect(map.platforms, isNotEmpty);
      expect(map.checkpoints.length, 3);
      expect(map.hammers.length, 1);
      expect(map.walls, isNotEmpty);
      for (final wall in map.walls) {
        expect(
          wall.width,
          greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
        );
        expect(
          wall.height,
          greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
        );
      }

      // Checkpoints ordered along the course (ascending x), finish beyond
      // the last checkpoint, kill line below every platform top.
      var previousX = map.spawnPoint.x;
      for (final checkpoint in map.checkpoints) {
        expect(checkpoint.x, greaterThan(previousX));
        previousX = checkpoint.x;
      }
      expect(map.finishLine.center.x, greaterThan(previousX));
      for (final platform in map.platforms) {
        expect(map.killY, lessThan(platform.center.y + platform.height / 2));
      }
    });
  });
}
