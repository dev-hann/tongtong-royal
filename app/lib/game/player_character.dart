import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Forge2D-backed player body with the movement verbs of the
/// architecture doc § 5 physics standards.
///
/// Pure Forge2D (no Flame): the host simulation and headless tests
/// drive it through CharacterWorld. The body is a dynamic
/// [widthMeters] x [heightMeters] box, `bullet: true` for CCD, with
/// fixed rotation (platformer feel — it never tips over). All tuning
/// numbers come from [PhysicsConsts].
class PlayerCharacter {
  /// Creates the body in [_world] at [position] (defaults to origin).
  PlayerCharacter(this._world, {Vector2? position}) {
    _body = _world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: (position ?? Vector2.zero()).clone(),
        bullet: true,
        fixedRotation: true,
      ),
    );
    final shape = PolygonShape()..setAsBoxXY(widthMeters / 2, heightMeters / 2);
    _body.createFixture(
      FixtureDef(
        shape,
        density: referenceMassKg / (widthMeters * heightMeters),
        friction: PhysicsConsts.playerGroundFriction,
        restitution: PhysicsConsts.restitutionGround,
      ),
    );
  }

  /// Player collision box width, meters.
  static const double widthMeters = 0.6;

  /// Player collision box height, meters (~1.5 m tall players).
  static const double heightMeters = 1.5;

  /// Reference player mass in kg. Matches the mass assumed by the
  /// [PhysicsConsts.jumpImpulse] documentation.
  static const double referenceMassKg = 65;

  /// A contact whose normal is within ~60 degrees of vertical counts
  /// as ground under the player. Geometric classification, not
  /// gameplay tuning.
  static const double _groundNormalYMinimum = 0.5;

  final World _world;

  late final Body _body;

  final WorldManifold _worldManifold = WorldManifold();

  /// True when a ground-like contact supports the player this tick.
  bool grounded = false;

  /// Sticky flag set by [enforceLimits] when the body exploded (NaN
  /// or out-of-bounds state). Cleared by the host after respawn.
  bool needsRespawn = false;

  /// The underlying Forge2D body (read surface for renderers and
  /// simulation code; treat as read-only outside this class).
  Body get body => _body;

  /// Applies the continuous ground movement force along [dir],
  /// scaled down so the velocity component along [dir] never
  /// exceeds [PhysicsConsts.moveMaxSpeed].
  void applyMove(Vector2 dir) {
    if (dir.length2 <= 0) {
      return;
    }
    final d = dir.normalized();
    final along = body.linearVelocity.dot(d);
    if (along >= PhysicsConsts.moveMaxSpeed) {
      return;
    }
    final accelPerTick =
        PhysicsConsts.moveForce / body.mass * PhysicsConsts.fixedDt;
    final remaining = PhysicsConsts.moveMaxSpeed - along;
    final effectiveForce = accelPerTick > remaining
        ? PhysicsConsts.moveForce * remaining / accelPerTick
        : PhysicsConsts.moveForce;
    body.applyForce(d * effectiveForce);
  }

  /// Applies the vertical jump impulse, only while [grounded].
  void jump() {
    if (!grounded) {
      return;
    }
    body.applyLinearImpulse(Vector2(0, PhysicsConsts.jumpImpulse));
  }

  /// Applies the dash impulse along [dir]. The resulting velocity
  /// is still capped by [enforceLimits] every tick.
  void dash(Vector2 dir) {
    if (dir.length2 <= 0) {
      return;
    }
    body.applyLinearImpulse(dir.normalized() * PhysicsConsts.dashImpulse);
  }

  /// Per-tick guard (architecture doc § 5): clamps linear and
  /// angular velocity via [PhysicsGuards] and flags [needsRespawn]
  /// for NaN/out-of-bounds state. Returns the current
  /// [needsRespawn].
  bool enforceLimits() {
    if (PhysicsGuards.isExplosive(body.position, body.linearVelocity)) {
      needsRespawn = true;
    }
    body.linearVelocity.setFrom(
      PhysicsGuards.clampLinearVelocity(body.linearVelocity),
    );
    body.angularVelocity = _clampAngular(body.angularVelocity);
    return needsRespawn;
  }

  /// Recomputes [grounded] from the world's current contacts.
  void updateGrounded() {
    var groundedNow = false;
    for (final contact in _world.contactManager.contacts) {
      final isA = contact.bodyA == body;
      if (!isA && contact.bodyB != body) {
        continue;
      }
      if (!contact.isTouching()) {
        continue;
      }
      contact.getWorldManifold(_worldManifold);
      // Box2D normals point from fixture A to fixture B; flip when
      // the player is fixture A so "up" always means ground below.
      final normalY = isA ? -_worldManifold.normal.y : _worldManifold.normal.y;
      if (normalY >= _groundNormalYMinimum) {
        groundedNow = true;
        break;
      }
    }
    grounded = groundedNow;
  }

  static double _clampAngular(double w) {
    if (!w.isFinite) {
      return 0;
    }
    return w.clamp(
      -PhysicsConsts.maxAngularVelocity,
      PhysicsConsts.maxAngularVelocity,
    );
  }
}
