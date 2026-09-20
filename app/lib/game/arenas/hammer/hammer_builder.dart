import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/character_world.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Callback for a raw arena sensor hit (architecture doc § 5:
/// sensors emit, callers judge). No points, ranks, or rules here.
/// Kill-ring touches and mallet-head contacts both route here —
/// both are elimination-class (hammer-dodge.md § Qualification).
typedef OnPlayerEliminated = void Function(PlayerId playerId);

/// UserData marker identifying a kill-ring sensor fixture.
final class _KillRingTag {
  const _KillRingTag();
}

const _killRingTag = _KillRingTag();

/// Builds a [HammerArenaMap] into a live [CharacterWorld]: the
/// tiered polygon-approximated circular platform (plus center slab),
/// the surrounding kill sensor ring, and kinematic mallet-head arms
/// on revolute-joint pivots at the platform center. Data in, bodies
/// out — no rules.
final class HammerArenaBuilder {
  /// Creates a builder routing sensor callbacks to [onPlayerEliminated].
  HammerArenaBuilder({required this.onPlayerEliminated});

  /// Callback receiving polled kill-ring and mallet-head hits.
  final OnPlayerEliminated onPlayerEliminated;

  // Ring coverage geometry: engineering bounds (a flung body must
  // overlap the volume for several ticks), not gameplay tuning. The
  // ring sits one gap beyond the initial kill radius so no standing
  // or falling-short player ever grazes it.
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
    if (map.platformThickness < PhysicsConsts.minWallThickness ||
        map.centerSlab.height < PhysicsConsts.minWallThickness) {
      throw ArgumentError.value(
        map.platformThickness,
        'map.platformThickness',
        'platform thinner than PhysicsConsts.minWallThickness',
      );
    }

    final tierRadii = map.shrink.tierRadii(map.platformRadius);
    final tiers = [
      for (final tierRadius in tierRadii)
        _buildPolygon(
          world,
          radius: tierRadius - map.platformThickness / 2,
          segmentCount: map.platformSegmentCount,
          thickness: map.platformThickness,
          isSensor: false,
        ),
    ];
    world.addStaticBox(
      center: map.centerSlab.center,
      width: map.centerSlab.width,
      height: map.centerSlab.height,
    );
    _buildPolygon(
      world,
      radius: map.initialKillRadius + _ringGap,
      segmentCount: map.platformSegmentCount,
      thickness: _ringThickness,
      isSensor: true,
    );
    final hammers = [for (final spec in map.hammers) _buildHammer(world, spec)];

    return BuiltArena._(
      world,
      onPlayerEliminated,
      resolvePlayer,
      hammers,
      tierRadii,
      tiers,
    );
  }

  /// Adds a regular polygon of [segmentCount] tangential boxes
  /// (chord radius [radius]) — the circular-shape approximation.
  static List<Body> _buildPolygon(
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
    return [
      for (var i = 0; i < segmentCount; i++)
        _buildSegment(world, corner(i), corner(i + 1), thickness, isSensor),
    ];
  }

  static Body _buildSegment(
    CharacterWorld world,
    Vector2 a,
    Vector2 b,
    double thickness,
    bool isSensor,
  ) {
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
    return body;
  }

  /// Kinematic mallet head on a revolute-joint pivot at the platform
  /// center: the body origin sits on the pivot and the head fixture
  /// spans the band `[radius - headLength, radius]` along the local
  /// +x axis (or the full bar `[0, radius]` for headless specs), so
  /// the scripted angular velocity sweeps it around the pivot like a
  /// clock hand.
  static Body _buildHammer(CharacterWorld world, HammerSpec spec) {
    final pivot = world.forgeWorld.createBody(
      BodyDef(position: spec.pivot.clone()),
    );
    final headLength = spec.headLength ?? spec.radius;
    final headInner = spec.radius - headLength;
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
        headLength / 2,
        spec.armThickness / 2,
        Vector2(headInner + headLength / 2, 0),
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

/// Live handle to a built arena: mallet-head bodies (for renderers
/// and bots), tier dropping as the rim shrinks, and contact polling
/// that routes kill-ring touches and mallet-head hits to the
/// builder's onPlayerEliminated callback.
final class BuiltArena {
  BuiltArena._(
    this._world,
    this._onPlayerEliminated,
    this._resolvePlayer,
    this.hammerBodies,
    this.tierRadii,
    this._tiers,
  ) : _dropped = List.filled(_tiers.length, false);

  final CharacterWorld _world;
  final OnPlayerEliminated _onPlayerEliminated;
  final PlayerId? Function(Body body) _resolvePlayer;
  final List<List<Body>> _tiers;
  final List<bool> _dropped;

  /// Kinematic mallet-head bodies, in map order.
  final List<Body> hammerBodies;

  /// Tier radii, outermost first (map data mirror).
  final List<double> tierRadii;

  /// Number of tiers still standing.
  int get activeTierCount => _dropped.where((d) => !d).length;

  /// Destroys every tier whose radius sits beyond [currentRadius].
  /// Idempotent: already-dropped tiers stay dropped. The innermost
  /// tier never drops for in-schedule radii (it equals the settled
  /// radius).
  void applyShrink(double currentRadius) {
    for (var i = 0; i < _tiers.length; i++) {
      if (_dropped[i] || tierRadii[i] <= currentRadius) {
        continue;
      }
      _dropped[i] = true;
      for (final body in _tiers[i]) {
        _world.forgeWorld.destroyBody(body);
      }
    }
  }

  /// Dispatches every currently-touching player-vs-kill-ring and
  /// player-vs-mallet-head contact to the builder's
  /// onPlayerEliminated callback. Call once per tick after the world
  /// step.
  void pollSensors() {
    // Copy: a dispatched elimination destroys the player body, which
    // mutates the world's contact list mid-iteration. One signal per
    // player per tick: overlapping sensor segments and dual
    // kill-ring/head contact on one body collapse to a single hit
    // (idempotent by playerId, hammer-dodge.md § Edge cases).
    final contacts =
        _world.forgeWorld.contactManager.contacts.toList(growable: false);
    final heads = hammerBodies.toSet();
    final reported = <PlayerId>{};
    for (final contact in contacts) {
      if (!contact.isTouching()) {
        continue;
      }
      _dispatchKillRing(contact.fixtureA, contact.fixtureB, reported);
      _dispatchKillRing(contact.fixtureB, contact.fixtureA, reported);
      _dispatchHead(contact.bodyA, contact.fixtureB, heads, reported);
      _dispatchHead(contact.bodyB, contact.fixtureA, heads, reported);
    }
  }

  void _dispatchKillRing(
    Fixture sensorCandidate,
    Fixture other,
    Set<PlayerId> reported,
  ) {
    if (!sensorCandidate.isSensor) {
      return;
    }
    if (sensorCandidate.userData is! _KillRingTag) {
      return;
    }
    final playerId = _resolvePlayer(other.body);
    if (playerId == null || !reported.add(playerId)) {
      return;
    }
    _onPlayerEliminated(playerId);
  }

  void _dispatchHead(
    Body headCandidate,
    Fixture other,
    Set<Body> heads,
    Set<PlayerId> reported,
  ) {
    if (!heads.contains(headCandidate)) {
      return;
    }
    final playerId = _resolvePlayer(other.body);
    if (playerId == null || !reported.add(playerId)) {
      return;
    }
    _onPlayerEliminated(playerId);
  }
}
