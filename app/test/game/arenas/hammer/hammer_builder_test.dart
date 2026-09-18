import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_builder.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/character_world.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

final class _RecordedEvents {
  final List<PlayerId> eliminated = [];

  void onPlayerEliminated(PlayerId playerId) {
    eliminated.add(playerId);
  }

  HammerArenaBuilder get builder =>
      HammerArenaBuilder(onPlayerEliminated: onPlayerEliminated);
}

double _normalized(double angle) {
  var a = angle % (2 * math.pi);
  if (a < -math.pi) {
    a += 2 * math.pi;
  } else if (a >= math.pi) {
    a -= 2 * math.pi;
  }
  return a;
}

HammerArenaMap _thinPlatformMap() {
  final base = HammerArenaMap.hammerArena(1);
  return HammerArenaMap(
    mapSeed: base.mapSeed,
    platformRadius: base.platformRadius,
    platformSegmentCount: base.platformSegmentCount,
    platformThickness: PhysicsConsts.minWallThickness - 0.1,
    killRadius: base.killRadius,
    spawnPoints: base.spawnPoints,
    hammers: base.hammers,
  );
}

void main() {
  group('HammerArenaBuilder', () {
    test('builds the arena without exceptions', () {
      final world = CharacterWorld();
      final builder = _RecordedEvents().builder;

      final arena = builder.build(
        world,
        HammerArenaMap.hammerArena(7),
        resolvePlayer: (body) => null,
      );

      expect(arena.hammerBodies, hasLength(2));
    });

    test('platform approximated by 16 static boxes plus kill ring',
        () {
      final world = CharacterWorld();
      final builder = _RecordedEvents().builder;
      final map = HammerArenaMap.hammerArena(7);

      builder.build(world, map, resolvePlayer: (body) => null);

      // 16 platform segments + 16 ring sensors; the two hammer pivot
      // anchors are static bodies too.
      var solidSegments = 0;
      var sensorSegments = 0;
      for (final body in world.forgeWorld.bodies) {
        final sensors = body.fixtures.where((f) => f.isSensor);
        if (sensors.isNotEmpty) {
          sensorSegments++;
        } else if (body.bodyType == BodyType.static) {
          solidSegments++;
        }
      }

      expect(sensorSegments, 16);
      expect(solidSegments, 16 + map.hammers.length);
    });

    test('hammer arms are kinematic, start at their seeded angle and '
        'rotate', () {
      final world = CharacterWorld();
      final builder = _RecordedEvents().builder;
      final map = HammerArenaMap.hammerArena(9);
      final arena = builder.build(
        world,
        map,
        resolvePlayer: (body) => null,
      );

      for (var i = 0; i < arena.hammerBodies.length; i++) {
        expect(arena.hammerBodies[i].bodyType, BodyType.kinematic);
        expect(
          _normalized(arena.hammerBodies[i].angle),
          closeTo(_normalized(map.hammers[i].initialAngle), 1e-9),
          reason: 'arm $i did not start at its seeded angle',
        );
      }

      for (var t = 0; t < 30; t++) {
        world.step();
      }

      for (var i = 0; i < arena.hammerBodies.length; i++) {
        final hammer = arena.hammerBodies[i];
        final spec = map.hammers[i];
        expect(
          (hammer.angle - spec.initialAngle).abs(),
          greaterThan(0.05),
          reason: 'arm $i never advanced from its initial angle',
        );
        expect(
          _normalized(hammer.angle - spec.initialAngle) *
              spec.angularSpeed,
          greaterThan(0),
          reason: 'arm $i rotates against its signed speed',
        );
      }
    });

    test('rejects platforms thinner than minWallThickness', () {
      final world = CharacterWorld();
      final builder = _RecordedEvents().builder;

      expect(
        () => builder.build(
          world,
          _thinPlatformMap(),
          resolvePlayer: (body) => null,
        ),
        throwsArgumentError,
      );
    });

    test('kill ring poll reports a player touching the ring', () {
      final world = CharacterWorld();
      final events = _RecordedEvents();
      final builder = events.builder;
      final map = HammerArenaMap.hammerArena(7);
      final arena = builder.build(world, map, resolvePlayer: (body) => 'p1');

      // Drop a player onto the ring (first spawn angle direction,
      // at the ring radius), then step until the sensor touches.
      final direction = map.spawnPoints.first.normalized();
      world.spawnPlayer(position: direction * (map.killRadius + 1));

      for (var i = 0; i < 10 && events.eliminated.isEmpty; i++) {
        world.step();
        arena.pollSensors();
      }

      expect(events.eliminated, ['p1']);
    });
  });
}
