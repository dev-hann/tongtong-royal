import 'dart:math' as math;

import 'package:app/game/character_world.dart';
import 'package:app/game/course/course_builder.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

final class _RecordedEvents implements CourseEvents {
  final List<PlayerId> fell = [];
  final List<PlayerId> hammerHits = [];

  @override
  void onPlayerFell(PlayerId playerId) => fell.add(playerId);

  @override
  void onCheckpoint(PlayerId playerId, int checkpointIndex) {}

  @override
  void onPlayerFinished(int tick, PlayerId playerId) {}

  @override
  void onPlayerHitByHammer(PlayerId playerId) => hammerHits.add(playerId);
}

CourseMap _thinWallMap() {
  return CourseMap(
    mapSeed: 1,
    spawnPoint: Vector2.zero(),
    checkpoints: const [],
    finishLine: BoxSpec(center: Vector2(10, 1), width: 1, height: 3),
    killY: -5,
    platforms: const [],
    walls: [
      BoxSpec(
        center: Vector2.zero(),
        width: PhysicsConsts.minWallThickness - 0.1,
        height: 3,
      ),
    ],
    hammers: const [],
  );
}

void main() {
  group('CourseBuilder', () {
    test('builds_the_trap_race_course_without_exceptions', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _RecordedEvents());

      final course = builder.build(
        world,
        CourseMap.trapRace(7),
        resolvePlayer: (body) => null,
      );

      expect(course.hammerBodies, hasLength(1));
    });

    test('hammer_body_is_kinematic_and_rotates_over_time', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _RecordedEvents());
      final course = builder.build(
        world,
        CourseMap.trapRace(7),
        resolvePlayer: (body) => null,
      );
      final hammer = course.hammerBodies.single;

      expect(hammer.bodyType, BodyType.kinematic);

      for (var i = 0; i < 30; i++) {
        world.step();
      }
      final angleAfterHalfSecond = hammer.angle;

      expect(angleAfterHalfSecond, greaterThan(0));

      for (var i = 0; i < 60; i++) {
        world.step();
      }

      expect(hammer.angle, greaterThan(angleAfterHalfSecond));
    });

    test('rejects_walls_thinner_than_minWallThickness', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _RecordedEvents());

      expect(
        () => builder.build(
          world,
          _thinWallMap(),
          resolvePlayer: (body) => null,
        ),
        throwsArgumentError,
      );
    });

    test('moving_walls_are_kinematic_and_follow_their_sinusoid', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _RecordedEvents());
      final map = CourseMap.trapRaceFinal(7, 2);

      final course = builder.build(world, map, resolvePlayer: (body) => null);

      final wallSpec = map.movingWalls.first;
      final wallBody = _wallBodyAt(world, wallSpec.center.x);
      expect(wallBody, isNotNull, reason: 'wall body built at its x');
      expect(wallBody!.bodyType, BodyType.kinematic);
      final quarterPeriodTicks =
          (wallSpec.period * PhysicsConsts.tickRate / 4).round();

      course.advanceWalls(0);
      final yAtZero = wallBody.position.y;
      course.advanceWalls(quarterPeriodTicks);
      final yAtQuarter = wallBody.position.y;

      expect(
        yAtZero,
        closeTo(wallSpec.centerYAt(0), 1e-9),
        reason: 'wall starts on its curve',
      );
      expect(
        yAtQuarter,
        closeTo(
          wallSpec.centerYAt(quarterPeriodTicks * PhysicsConsts.fixedDt),
          1e-9,
        ),
        reason: 'wall follows the sinusoid a quarter period later',
      );
      expect(
        yAtQuarter,
        greaterThan(yAtZero),
        reason: 'first wall moves up over the first quarter period',
      );
    });

    test('hammer_contact_poll_dispatches_onPlayerHitByHammer', () {
      final world = CharacterWorld();
      final events = _RecordedEvents();
      final builder = CourseBuilder(events: events);
      final map = CourseMap.trapRace(7);

      final course = builder.build(world, map, resolvePlayer: (body) => 'p1');

      // Freeze the hammer pointing straight down (tip grazing the
      // surface) and drop a player into its column at pivot.x.
      final hammer = course.hammerBodies.single;
      final spec = map.hammers.single;
      hammer.angularVelocity = 0;
      hammer.setTransform(hammer.position, -math.pi / 2);
      world
        ..spawnPlayer(position: Vector2(spec.pivot.x, 1))
        ..step();
      course.pollSensors(1);

      expect(events.hammerHits, isNotEmpty);
    });
  });
}

Body? _wallBodyAt(CharacterWorld world, double x) {
  for (final body in world.forgeWorld.bodies) {
    if (body.bodyType == BodyType.kinematic &&
        (body.position.x - x).abs() < 1e-9) {
      return body;
    }
  }
  return null;
}
