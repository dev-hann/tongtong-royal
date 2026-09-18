import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/character_world.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Callback for a raw arena sensor hit (architecture doc § 5:
/// sensors emit, callers judge). No points, ranks, or rules here.
typedef OnPlayerEliminated = void Function(PlayerId playerId);

/// UserData marker identifying a kill-ring sensor fixture.
final class _KillRingTag {
  const _KillRingTag();
}

const _killRingTag = _KillRingTag();

/// Builds a [HammerArenaMap] into a live [CharacterWorld]: the
/// polygon-approximated circular platform, the surrounding kill
/// sensor ring, and kinematic hammer arms on a revolute-joint pivot
/// at the platform center. Data in, bodies out — no rules.
final class HammerArenaBuilder {
  /// Creates a builder routing sensor callbacks to [onPlayerEliminated].
  HammerArenaBuilder({required this.onPlayerEliminated});

  /// Callback receiving polled kill-ring hits.
  final OnPlayerEliminated onPlayerEliminated;

  // Ring coverage geometry: engineering bounds (a flung body must
  // overlap the volume for several ticks), not gameplay tuning. The
  // ring sits one gap beyond the kill radius so no standing or
  // falling-short player ever grazes it.
  static const double _ringThickness = 1;
  static const double _ringGap = 1;
  static const double _segmentOverlap = 0.1;

  /// Builds [map] into [world]. [resolvePlayer] maps a Forge2D body
  /// to its player id (null for non-players); it is used when
  /// polling sensor contacts. Returns the live arena handle.
  BuiltArena build(
    CharacterWorld world,
    HammerArenaMap map, {
    required PlayerId? Function(Body body) resolvePlayer,
  }) {
    if (map.platformThickness < PhysicsConsts.minWallThickness) {
      throw ArgumentError.value(
        map.platformThickness,
        'map.platformThickness',
        'platform thinner than PhysicsConsts.minWallThickness',
      );
    }

    _buildPolygon(
      world,
      radius: map.platformRadius - map.platformThickness / 2,
      segmentCount: map.platformSegmentCount,
      thickness: map.platformThickness,
      isSensor: false,
    );
    _buildPolygon(
      world,
      radius: map.killRadius + _ringGap,
      segmentCount: map.platformSegmentCount,
      thickness: _ringThickness,
      isSensor: true,
    );
    final hammers = [for (final spec in map.hammers) _buildHammer(world, spec)];

    return BuiltArena._(world, onPlayerEliminated, resolvePlayer, hammers);
  }

  /// Adds a regular polygon of [segmentCount] tangential boxes
  /// (chord radius [radius]) — the circular-shape approximation.
  static void _buildPolygon(
    CharacterWorld world, {
    required double radius,
    required int segmentCount,
    required double thickness,
    required bool isSensor,
  }) {
    Vector2 corner(int i) => Vector2(
          radius * math.cos(2 * math.pi * i / segmentCount),
          radius * math.sin(2 * math.pi * i / segmentCount),
        );
    for (var i = 0; i < segmentCount; i++) {
      final a = corner(i);
      final b = corner(i + 1);
      final center = (a + b) / 2;
      final angle = math.atan2(b.y - a.y, b.x - a.x);
      final body = world.forgeWorld.createBody(
        BodyDef(position: center, angle: angle),
      );
      final shape = PolygonShape()
        ..setAsBoxXY((b - a).length / 2 + _segmentOverlap, thickness / 2);
      body.createFixture(
        FixtureDef(
          shape,
          friction: PhysicsConsts.playerGroundFriction,
          restitution: PhysicsConsts.restitutionGround,
          isSensor: isSensor,
          userData: isSensor ? _killRingTag : null,
        ),
      );
    }
  }

  /// Kinematic arm on a revolute-joint pivot at the platform center:
  /// the body origin sits on the pivot and the fixture extends
  /// half a radius along the local +x axis, so the scripted angular
  /// velocity sweeps the arm around the pivot like a clock hand.
  static Body _buildHammer(CharacterWorld world, HammerSpec spec) {
    final pivot = world.forgeWorld.createBody(
      BodyDef(position: spec.pivot.clone()),
    );
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
}

/// Live handle to a built arena: hammer bodies (for renderers) and
/// contact polling that routes kill-ring touches to the builder's
/// onPlayerEliminated callback.
final class BuiltArena {
  BuiltArena._(
    this._world,
    this._onPlayerEliminated,
    this._resolvePlayer,
    this.hammerBodies,
  );

  final CharacterWorld _world;
  final OnPlayerEliminated _onPlayerEliminated;
  final PlayerId? Function(Body body) _resolvePlayer;

  /// Kinematic hammer arm bodies, in map order.
  final List<Body> hammerBodies;

  /// Dispatches every currently-touching player-vs-kill-ring
  /// contact to the builder's onPlayerEliminated callback. Call
  /// once per tick after the world step.
  void pollSensors() {
    // Copy: a dispatched elimination destroys the player body, which
    // mutates the world's contact list mid-iteration.
    final contacts =
        _world.forgeWorld.contactManager.contacts.toList(growable: false);
    for (final contact in contacts) {
      if (!contact.isTouching()) {
        continue;
      }
      _dispatch(contact.fixtureA, contact.fixtureB);
      _dispatch(contact.fixtureB, contact.fixtureA);
    }
  }

  void _dispatch(Fixture sensorCandidate, Fixture other) {
    if (!sensorCandidate.isSensor) {
      return;
    }
    if (sensorCandidate.userData is! _KillRingTag) {
      return;
    }
    final playerId = _resolvePlayer(other.body);
    if (playerId == null) {
      return;
    }
    _onPlayerEliminated(playerId);
  }
}
