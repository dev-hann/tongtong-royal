import 'package:tongtong_shared/src/physics/physics_guards.dart';
import 'package:vector_math/vector_math_64.dart';

/// A single tick of player input, already sanitized.
///
/// Construction runs [moveDir] through [PhysicsGuards.sanitizeJoystick],
/// so consumers (controller, host simulation) can trust the vector:
/// finite, each component within [-1, 1]. [jumpPressed] and
/// [dashPressed] are edge signals — true only on the tick the button
/// went down.
final class PlayerInputState {
  /// Builds an input state, sanitizing [moveDir] via
  /// [PhysicsGuards.sanitizeJoystick].
  PlayerInputState({
    Vector2? moveDir,
    this.jumpPressed = false,
    this.dashPressed = false,
  }) : moveDir = PhysicsGuards.sanitizeJoystick(
          moveDir ?? Vector2.zero(),
        );

  /// Sanitized movement direction (components in [-1, 1]).
  final Vector2 moveDir;

  /// True only on the tick the jump button was pressed.
  final bool jumpPressed;

  /// True only on the tick the dash button was pressed.
  final bool dashPressed;
}
