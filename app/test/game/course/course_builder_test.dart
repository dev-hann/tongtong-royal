import 'package:app/game/character_world.dart';
import 'package:app/game/course/course_builder.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

final class _NoopEvents implements CourseEvents {
  @override
  void onPlayerFell(PlayerId playerId) {}

  @override
  void onCheckpoint(PlayerId playerId, int checkpointIndex) {}

  @override
  void onPlayerFinished(int tick, PlayerId playerId) {}
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
    test('builds the trap race course without exceptions', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _NoopEvents());

      final course = builder.build(
        world,
        CourseMap.trapRace(7),
        resolvePlayer: (body) => null,
      );

      expect(course.hammerBodies, hasLength(1));
    });

    test('hammer body is kinematic and rotates over time', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _NoopEvents());
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

    test('rejects walls thinner than minWallThickness', () {
      final world = CharacterWorld();
      final builder = CourseBuilder(events: _NoopEvents());

      expect(
        () =>
            builder.build(world, _thinWallMap(), resolvePlayer: (body) => null),
        throwsArgumentError,
      );
    });
  });
}
