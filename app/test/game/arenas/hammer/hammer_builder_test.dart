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

/// Steps [world] [times] times (helper keeps the cascade lint calm
/// in tight arrange blocks).
void stepWorld(CharacterWorld world, [int times = 1]) {
  for (var i = 0; i < times; i++) {
    world.step();
  }
}

/// Applies [radius] and returns the standing tier count (helper:
/// alternating shrink/read statements trip the cascade lint).
int shrinkAndCount(BuiltArena arena, double radius) {
  arena.applyShrink(radius);
  return arena.activeTierCount;
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

HammerArenaMap _mapWithThickness(double thickness) {
  final base = HammerArenaMap.hammerArena(1);
  return HammerArenaMap(
    mapSeed: base.mapSeed,
    platformRadius: base.platformRadius,
    platformSegmentCount: base.platformSegmentCount,
    platformThickness: thickness,
    killRingMargin: base.killRingMargin,
    shrink: base.shrink,
    centerSlab: base.centerSlab,
    spawnPoints: base.spawnPoints,
    hammers: base.hammers,
  );
}

void main() {
  group('HammerArenaBuilder', () {
    test('builds_tiered_platform_hammers_and_kill_ring', () {
      final world = CharacterWorld();
      final map = HammerArenaMap.hammerArena(7);

      final arena = _RecordedEvents().builder.build(
        world,
        map,
        resolvePlayer: (body) => null,
      );

      expect(arena.hammerBodies, hasLength(2));
      expect(arena.tierRadii, map.shrink.tierRadii(map.platformRadius));
      expect(arena.activeTierCount, map.shrink.tierCount);
      // 16 segment boxes per tier + the center slab + two hammer
      // pivot anchors are the static bodies; the 16-segment kill
      // ring at the outer bound is sensor-only.
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
      expect(sensorSegments, map.platformSegmentCount);
      expect(
        solidSegments,
        map.platformSegmentCount * map.shrink.tierCount +
            1 +
            map.hammers.length,
      );
    });

    test('mallet_heads_are_kinematic_start_seeded_and_rotate', () {
      final world = CharacterWorld();
      final map = HammerArenaMap.hammerArena(9);
      final arena = _RecordedEvents().builder.build(
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
          _normalized(hammer.angle - spec.initialAngle) * spec.angularSpeed,
          greaterThan(0),
          reason: 'arm $i rotates against its signed speed',
        );
      }
    });

    test('rejects_platforms_thinner_than_minWallThickness', () {
      final world = CharacterWorld();
      final thin = _mapWithThickness(PhysicsConsts.minWallThickness - 0.1);

      expect(
        () => _RecordedEvents().builder.build(
          world,
          thin,
          resolvePlayer: (body) => null,
        ),
        throwsArgumentError,
      );
    });

    test('applyShrink_drops_only_tiers_beyond_the_current_radius', () {
      final world = CharacterWorld();
      final map = HammerArenaMap.hammerArena(7);
      final arena = _RecordedEvents().builder.build(
        world,
        map,
        resolvePlayer: (body) => null,
      );

      final afterOuter = shrinkAndCount(arena, 6.99);
      final afterSettled = shrinkAndCount(arena, 4.5);

      expect(afterOuter, 4, reason: 'rim passed the outer tier');
      expect(afterSettled, 1, reason: 'settled tier only');
    });

    test('applyShrink_is_idempotent_per_radius', () {
      final world = CharacterWorld();
      final map = HammerArenaMap.hammerArena(7);
      final arena = _RecordedEvents().builder.build(
        world,
        map,
        resolvePlayer: (body) => null,
      );

      final firstDrop = shrinkAndCount(arena, 5.5);

      // Same radius again: the drop must be a no-op.
      final repeatDrop = shrinkAndCount(arena, 5.5);

      expect(repeatDrop, firstDrop);
      expect(firstDrop, 2);
    });

    test('kill_ring_poll_reports_a_player_touching_the_ring', () {
      final world = CharacterWorld();
      final events = _RecordedEvents();
      final map = HammerArenaMap.hammerArena(7);
      final arena = events.builder.build(
        world,
        map,
        resolvePlayer: (body) => 'p1',
      );

      final direction = map.spawnPoints.first.normalized();
      world.spawnPlayer(position: direction * (map.initialKillRadius + 1));

      for (var i = 0; i < 10 && events.eliminated.isEmpty; i++) {
        world.step();
        arena.pollSensors();
      }

      expect(events.eliminated, ['p1']);
    });

    test('mallet_head_contact_poll_reports_the_hit_player', () {
      final world = CharacterWorld();
      final events = _RecordedEvents();
      final map = HammerArenaMap.hammerArena(7);
      final arena = events.builder.build(
        world,
        map,
        resolvePlayer: (body) => 'p1',
      );

      // Freeze the first mallet pointing straight up so its head
      // occupies the column above the rim step, then drop a player
      // onto it.
      arena.hammerBodies.first
        ..angularVelocity = 0
        ..setTransform(Vector2(0, 0), math.pi / 2);
      final tipRadius = map.hammers.first.radius;
      world.spawnPlayer(
        position: Vector2(0, tipRadius - 0.1 + 0.75),
      );

      stepWorld(world, 2);
      arena.pollSensors();

      expect(events.eliminated, ['p1']);
    });
  });
}
