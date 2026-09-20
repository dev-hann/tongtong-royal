import 'dart:math' as math;

import 'package:app/game/character_world.dart';
import 'package:app/game/course/course_map.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Sink for raw course sensor callbacks (architecture doc § 5:
/// sensors emit, callers judge). No points, ranks, or rules here.
abstract interface class CourseEvents {
  /// A player entered a fall zone (kill volume).
  void onPlayerFell(PlayerId playerId);

  /// A player touched checkpoint [checkpointIndex]
  /// (0-based into [CourseMap.checkpoints]).
  void onCheckpoint(PlayerId playerId, int checkpointIndex);

  /// A player crossed the finish line at simulation tick [tick].
  void onPlayerFinished(int tick, PlayerId playerId);

  /// A player touched a rotating hammer arm. Knockback-only in R1
  /// (standard); elimination-class in the FINAL variant, where the
  /// simulation decides (trap-race.md § Edge cases).
  void onPlayerHitByHammer(PlayerId playerId);
}

/// Kind of a course sensor fixture.
enum _SensorKind { kill, checkpoint, finish }

/// UserData payload identifying a sensor fixture during polling.
final class _SensorTag {
  const _SensorTag(this.kind, this.index);

  final _SensorKind kind;

  /// Checkpoint index; -1 for non-checkpoint sensors.
  final int index;
}

/// Builds a [CourseMap] into a live [CharacterWorld]: static boxes,
/// sensor fixtures (kill volume, checkpoints, finish) and kinematic
/// hammers on revolute joints. Data in, bodies out — no rules.
final class CourseBuilder {
  /// Creates a builder routing sensor callbacks to [events].
  CourseBuilder({required this.events});

  /// Sink receiving polled sensor callbacks.
  final CourseEvents events;

  // Sensor coverage geometry: engineering bounds (a fast-falling
  // body must overlap the volume for several ticks), not gameplay
  // tuning.
  static const double _killVolumeMargin = 5;
  static const double _killVolumeDepth = 15;
  static const double _checkpointSensorWidth = 0.6;
  static const double _checkpointSensorHeight = 2.5;

  /// Builds [map] into [world]. [resolvePlayer] maps a Forge2D body
  /// to its player id (null for non-players); it is used when polling
  /// sensor contacts. Returns the live course handle.
  BuiltCourse build(
    CharacterWorld world,
    CourseMap map, {
    required PlayerId? Function(Body body) resolvePlayer,
  }) {
    for (final wall in map.walls) {
      if (wall.width < PhysicsConsts.minWallThickness ||
          wall.height < PhysicsConsts.minWallThickness) {
        throw ArgumentError.value(
          wall,
          'map.walls',
          'wall thinner than PhysicsConsts.minWallThickness',
        );
      }
    }

    for (final platform in map.platforms) {
      world.addStaticBox(
        center: platform.center,
        width: platform.width,
        height: platform.height,
      );
    }
    for (final wall in map.walls) {
      world.addStaticBox(
        center: wall.center,
        width: wall.width,
        height: wall.height,
      );
    }

    _addSensor(
      world.forgeWorld,
      center: _killVolumeCenter(map),
      width: _killVolumeWidth(map),
      height: _killVolumeDepth,
      tag: const _SensorTag(_SensorKind.kill, -1),
    );
    for (var i = 0; i < map.checkpoints.length; i++) {
      _addSensor(
        world.forgeWorld,
        center: map.checkpoints[i],
        width: _checkpointSensorWidth,
        height: _checkpointSensorHeight,
        tag: _SensorTag(_SensorKind.checkpoint, i),
      );
    }
    _addSensor(
      world.forgeWorld,
      center: map.finishLine.center,
      width: map.finishLine.width,
      height: map.finishLine.height,
      tag: const _SensorTag(_SensorKind.finish, -1),
    );
    final hammers = [for (final spec in map.hammers) _buildHammer(world, spec)];
    final movingWalls = [
      for (final spec in map.movingWalls)
        (_buildMovingWall(world, spec), spec),
    ];

    return BuiltCourse._(
      world,
      events,
      resolvePlayer,
      hammers,
      movingWalls,
    );
  }

  static Vector2 _killVolumeCenter(CourseMap map) {
    final (minX, maxX) = _courseBounds(map);
    return Vector2((minX + maxX) / 2, map.killY - _killVolumeDepth / 2);
  }

  static double _killVolumeWidth(CourseMap map) {
    final (minX, maxX) = _courseBounds(map);
    return maxX - minX + 2 * _killVolumeMargin;
  }

  /// Returns (minX, maxX) over all platforms and walls.
  static (double, double) _courseBounds(CourseMap map) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    for (final box in [...map.platforms, ...map.walls]) {
      minX = math.min(minX, box.center.x - box.width / 2);
      maxX = math.max(maxX, box.center.x + box.width / 2);
    }
    return (minX, maxX);
  }

  static Fixture _addSensor(
    World world, {
    required Vector2 center,
    required double width,
    required double height,
    required _SensorTag tag,
  }) {
    final body = world.createBody(BodyDef(position: center.clone()));
    final shape = PolygonShape()..setAsBoxXY(width / 2, height / 2);
    return body.createFixture(FixtureDef(shape, isSensor: true, userData: tag));
  }

  static Body _buildHammer(CharacterWorld world, HammerSpec spec) {
    final pivot = world.forgeWorld.createBody(
      BodyDef(position: spec.pivot.clone()),
    );
    // The arm origin sits on the pivot and the fixture extends a
    // full radius along the local +x axis, so the scripted angular
    // velocity sweeps the arm around the pivot like a clock hand and
    // the tip reaches `pivot.y - radius` (map data lifts the pivot
    // so the tip grazes the running surface).
    final arm = world.forgeWorld.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: spec.pivot.clone(),
        angle: spec.initialAngle,
        // Forge2D joint motors cannot drive kinematic bodies (their
        // inverse inertia is zero), so the arm rotates via its set
        // angular velocity; the motor below still records the spec
        // speed on the joint per the architecture's hammer standard.
        angularVelocity: spec.angularSpeed,
      ),
    );
    final shape = PolygonShape()
      ..setAsBox(
        spec.radius / 2,
        spec.armThickness / 2,
        Vector2(spec.radius / 2, 0),
        0,
      );
    arm.createFixture(
      FixtureDef(
        shape,
        friction: PhysicsConsts.playerGroundFriction,
        restitution: PhysicsConsts.restitutionGround,
      ),
    );

    final jointDef = RevoluteJointDef()
      ..initialize(pivot, arm, spec.pivot.clone())
      ..enableMotor = true
      ..motorSpeed = spec.angularSpeed
      ..maxMotorTorque = spec.maxMotorTorque;
    world.forgeWorld.createJoint(RevoluteJoint(jointDef));
    return arm;
  }

  /// Kinematic squeeze-gate wall: position is scripted per tick by
  /// [BuiltCourse.advanceWalls] from the spec's sinusoid (a joint
  /// motor cannot express oscillation, and setTransform keeps the
  /// wall exactly on its curve at the fixed timestep).
  static Body _buildMovingWall(CharacterWorld world, MovingWallSpec spec) {
    final body = world.forgeWorld.createBody(
      BodyDef(
        type: BodyType.kinematic,
        position: Vector2(spec.center.x, spec.centerYAt(0)),
      ),
    );
    final shape = PolygonShape()
      ..setAsBoxXY(spec.width / 2, spec.height / 2);
    body.createFixture(
      FixtureDef(
        shape,
        friction: PhysicsConsts.playerGroundFriction,
        restitution: PhysicsConsts.restitutionGround,
      ),
    );
    return body;
  }
}

/// Live handle to a built course: hammer bodies (for renderers),
/// scripted squeeze-gate walls, and contact polling that routes
/// sensor touches into [CourseEvents].
final class BuiltCourse {
  BuiltCourse._(
    this._world,
    this._events,
    this._resolvePlayer,
    this.hammerBodies,
    this._movingWalls,
  );

  final CharacterWorld _world;
  final CourseEvents _events;
  final PlayerId? Function(Body body) _resolvePlayer;
  final List<(Body, MovingWallSpec)> _movingWalls;

  /// Kinematic hammer arm bodies, in map order.
  final List<Body> hammerBodies;

  /// Scripts every squeeze-gate wall to its curve position for
  /// [tick]. Call once per tick before the world step.
  void advanceWalls(int tick) {
    final seconds = tick * PhysicsConsts.fixedDt;
    for (final (body, spec) in _movingWalls) {
      body.setTransform(
        Vector2(spec.center.x, spec.centerYAt(seconds)),
        0,
      );
    }
  }

  /// Dispatches every currently-touching player-vs-sensor contact to
  /// the builder's [CourseEvents] sink, plus player-vs-hammer-arm
  /// touches to [CourseEvents.onPlayerHitByHammer]. Call once per
  /// tick after the world step. [tick] is the current simulation
  /// tick, stamped on finish events.
  void pollSensors(int tick) {
    // Copy: a FINAL-mode hammer-hit elimination destroys the player
    // body, which mutates the contact list mid-iteration.
    final contacts =
        _world.forgeWorld.contactManager.contacts.toList(growable: false);
    final hammers = hammerBodies.toSet();
    for (final contact in contacts) {
      if (!contact.isTouching()) {
        continue;
      }
      _dispatch(contact.fixtureA, contact.fixtureB, tick);
      _dispatch(contact.fixtureB, contact.fixtureA, tick);
      _dispatchHammer(contact.bodyA, contact.fixtureB, hammers);
      _dispatchHammer(contact.bodyB, contact.fixtureA, hammers);
    }
  }

  void _dispatch(Fixture sensorCandidate, Fixture other, int tick) {
    if (!sensorCandidate.isSensor) {
      return;
    }
    final tag = sensorCandidate.userData;
    if (tag is! _SensorTag) {
      return;
    }
    final playerId = _resolvePlayer(other.body);
    if (playerId == null) {
      return;
    }
    switch (tag.kind) {
      case _SensorKind.kill:
        _events.onPlayerFell(playerId);
      case _SensorKind.checkpoint:
        _events.onCheckpoint(playerId, tag.index);
      case _SensorKind.finish:
        _events.onPlayerFinished(tick, playerId);
    }
  }

  void _dispatchHammer(
    Body hammerCandidate,
    Fixture other,
    Set<Body> hammers,
  ) {
    if (!hammers.contains(hammerCandidate)) {
      return;
    }
    final playerId = _resolvePlayer(other.body);
    if (playerId == null) {
      return;
    }
    _events.onPlayerHitByHammer(playerId);
  }
}
