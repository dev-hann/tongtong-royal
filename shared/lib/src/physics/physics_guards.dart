import 'package:tongtong_shared/src/physics/physics_consts.dart';
import 'package:vector_math/vector_math_64.dart';

/// Pure validation functions enforcing the physics standards of the
/// architecture doc § 5. No state, no I/O — safe to call from the host
/// simulation every tick and from the server relay path.
abstract final class PhysicsGuards {
  /// Returns a copy of [v] with its length capped at
  /// [PhysicsConsts.maxLinearVelocity]. Vectors with a NaN or infinite
  /// component collapse to `Vector2.zero()`.
  static Vector2 clampLinearVelocity(Vector2 v) {
    if (!_isFinite(v)) {
      return Vector2.zero();
    }
    if (v.length <= PhysicsConsts.maxLinearVelocity) {
      return v.clone();
    }
    return v.clone()
      ..normalize()
      ..scale(PhysicsConsts.maxLinearVelocity);
  }

  /// True when any component of [position] or [velocity] is NaN,
  /// infinite, or beyond [PhysicsConsts.worldBoundsTolerance]. Such a
  /// body is considered exploded and must be respawned.
  static bool isExplosive(Vector2 position, Vector2 velocity) {
    return _isOutOfBounds(position) || _isOutOfBounds(velocity);
  }

  /// Clamps each component of [input] to [-1, 1]. Any NaN or infinite
  /// component collapses the whole vector to zero (server-side input
  /// sanity before relay, network doc § 3).
  static Vector2 sanitizeJoystick(Vector2 input) {
    if (!_isFinite(input)) {
      return Vector2.zero();
    }
    return Vector2(
      input.x.clamp(-1, 1).toDouble(),
      input.y.clamp(-1, 1).toDouble(),
    );
  }

  static bool _isFinite(Vector2 v) => v.x.isFinite && v.y.isFinite;

  static bool _isOutOfBounds(Vector2 v) {
    if (!_isFinite(v)) {
      return true;
    }
    const bound = PhysicsConsts.worldBoundsTolerance;
    return v.x.abs() > bound || v.y.abs() > bound;
  }
}
