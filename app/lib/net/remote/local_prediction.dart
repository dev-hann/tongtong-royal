import 'dart:math' as math;

import 'package:app/net/remote/render_feed.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Reconciliation snap threshold, meters. Predictions farther than
/// this from the authoritative pose are wrong enough that blending
/// would look like teleporting anyway (a player is 0.6 m wide), so
/// the pose snaps. Below it, a light blend hides quantization and
/// small host/client divergence without visible rubber-banding.
const double predictionSnapThresholdMeters = 0.5;

/// Fraction of the remaining prediction error removed on each
/// reconciliation (one snapshot, ~20 Hz ≈ one frame). 0.1 converges
/// within a handful of snapshots while keeping corrections smooth.
const double predictionReconcileBlendFactor = 0.1;

/// Kinematic local-player prediction (architecture doc § 9: only the
/// local player may be predicted; remote players are interpolated
/// only).
///
/// MVP simplification (deliberate, per task): prediction integrates
/// `authoritative velocity + input direction × moveMaxSpeed` — no
/// gravity, no collisions, no physics engine. Host snapshots correct
/// drift: velocity is always adopted wholesale, position snaps past
/// [predictionSnapThresholdMeters] and blends below it.
final class LocalPrediction {
  /// Creates a prediction for the local [playerId].
  LocalPrediction({required this.playerId});

  /// The predicted player.
  final PlayerId playerId;

  double _x = 0;
  double _y = 0;
  double _angle = 0;
  double _vx = 0;
  double _vy = 0;
  bool _hasState = false;

  /// Whether an authoritative state has ever been seen.
  bool get hasState => _hasState;

  /// Current predicted pose (stale by construction until
  /// [integrate] runs).
  PlayerRenderPose get predictedPose =>
      PlayerRenderPose(x: _x, y: _y, angle: _angle);

  /// Reconciles against an [authoritative] snapshot state. The first
  /// snapshot seeds the prediction; afterwards, position snaps when
  /// the prediction error exceeds [predictionSnapThresholdMeters]
  /// and otherwise moves [predictionReconcileBlendFactor] of the way
  /// toward the authoritative pose. Velocity and angle are always
  /// adopted from the host (client never owns them).
  void applySnapshot(PlayerState authoritative) {
    if (!_hasState) {
      _adopt(authoritative);
      return;
    }
    final dx = authoritative.x - _x;
    final dy = authoritative.y - _y;
    if (math.sqrt(dx * dx + dy * dy) > predictionSnapThresholdMeters) {
      _adopt(authoritative);
      return;
    }
    _x += dx * predictionReconcileBlendFactor;
    _y += dy * predictionReconcileBlendFactor;
    _angle = authoritative.angle;
    _vx = authoritative.vx;
    _vy = authoritative.vy;
  }

  /// Advances the prediction by [dtSeconds] under [input]:
  /// `position += (authoritativeVelocity + moveDir × moveMaxSpeed)
  /// × dt`. No-ops before the first snapshot or for non-positive dt.
  void integrate({required PlayerInputState input, required double dtSeconds}) {
    if (!_hasState || dtSeconds <= 0) {
      return;
    }
    _x += (_vx + input.moveDir.x * PhysicsConsts.moveMaxSpeed) * dtSeconds;
    _y += (_vy + input.moveDir.y * PhysicsConsts.moveMaxSpeed) * dtSeconds;
  }

  void _adopt(PlayerState state) {
    _x = state.x;
    _y = state.y;
    _angle = state.angle;
    _vx = state.vx;
    _vy = state.vy;
    _hasState = true;
  }
}
