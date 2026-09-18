import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('HammerArenaMap.hammerArena', () {
    test('same seed produces identical arena data', () {
      final a = HammerArenaMap.hammerArena(42);
      final b = HammerArenaMap.hammerArena(42);

      expect(a, equals(b));
      expect(a.toJson(), equals(b.toJson()));
    });

    test('different seed jitters hammer phases', () {
      final a = HammerArenaMap.hammerArena(7).hammers;
      final b = HammerArenaMap.hammerArena(8).hammers;

      expect(
        a.map((h) => h.initialAngle).toList(),
        isNot(equals(b.map((h) => h.initialAngle).toList())),
      );
    });

    test('JSON roundtrip preserves the map', () {
      for (final seed in [0, 7, 42]) {
        final map = HammerArenaMap.hammerArena(seed);

        final restored = HammerArenaMap.fromJson(map.toJson());

        expect(restored, equals(map), reason: 'seed $seed');
      }
    });

    test('factory produces a small but complete arena', () {
      final map = HammerArenaMap.hammerArena(3);

      // Circular platform approximated by a 16-sided regular polygon.
      expect(map.platformSegmentCount, 16);
      expect(
        map.platformThickness,
        greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
      );
      expect(map.hammers, hasLength(2));
      for (final hammer in map.hammers) {
        expect(hammer.pivot.x, equals(0));
        expect(hammer.pivot.y, equals(0));
        // Arms reach the standable surface ring, not past the kill
        // radius.
        expect(hammer.radius, lessThan(map.killRadius));
      }
      expect(map.spawnPoints, hasLength(4));
      for (final spawn in map.spawnPoints) {
        expect(spawn.length, lessThan(map.killRadius));
      }
    });

    test('spawn points sit on the upper platform arc', () {
      final map = HammerArenaMap.hammerArena(5);

      for (final spawn in map.spawnPoints) {
        final angle = math.atan2(spawn.y, spawn.x) * 180 / math.pi;
        // Top pole is 90 degrees; spawns spread around it.
        expect(angle, greaterThan(45));
        expect(angle, lessThan(135));
        // Just above the platform surface, player-half-height clearance.
        expect(spawn.length, greaterThan(map.platformRadius));
        expect(spawn.length, lessThan(map.platformRadius + 1));
      }
    });

    test('hammer spec serializes its initial angle', () {
      final spec = HammerSpec(
        pivot: Vector2.zero(),
        radius: 7.1,
        angularSpeed: 1.2,
        initialAngle: 1.1,
      );

      final restored = HammerSpec.fromJson(spec.toJson());

      expect(restored, equals(spec));
      expect(restored.initialAngle, equals(1.1));
    });
  });
}
