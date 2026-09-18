import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/bots/bot_brain.dart';
// Vector2 is the repo-wide math type (same seam as
// touch_input_source.dart); no physics-engine types cross it.
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

/// Arm geometry from the map spec: pivot + reach. Live angle and
/// angular velocity arrive per tick via BotObservation.nearbyHazards.
typedef _ArmSpec = ({double x, double y, double radius});

/// Heuristic Hammer Dodge survivor (GDD § 9.2, basic difficulty):
/// steer toward the arena center, jump when a hazard arm's linear
/// angle extrapolation predicts it sweeping the bot's position
/// within the danger horizon, and wander a little so seeded bots
/// do not stack on one spot.
final class SurvivalBot implements BotBrain {
  /// Extracts the map knowledge this brain needs from [map]:
  /// arm pivots/reaches and the platform radius. [seed] drives the
  /// wander target sequence deterministically.
  factory SurvivalBot.fromArenaMap(HammerArenaMap map, {required int seed}) {
    return SurvivalBot._(seed, [
      for (final h in map.hammers)
        (x: h.pivot.x, y: h.pivot.y, radius: h.radius),
    ], map.platformRadius);
  }

  SurvivalBot._(this._seed, List<_ArmSpec> arms, double platformRadius)
    : _arms = List.unmodifiable(arms),
      _centerBandMeters = platformRadius * centerBandFraction;

  /// Band around the center, as a fraction of the platform radius,
  /// inside which the bot does not bother steering: ~3.2 m on the
  /// 7 m arena keeps it clear of the rim where hammers launch
  /// players off.
  static const double centerBandFraction = 0.45;

  /// Prediction horizon, ticks: an arm reaching the bot within
  /// ~0.42 s (at [PhysicsConsts.tickRate]) triggers the jump —
  /// about the lead a jump needs to be airborne at arrival.
  static const int dangerTicks = 25;

  /// Slack on the arm-reach check, meters (half a player width):
  /// bots standing just past an arm's tip circle still treat it as
  /// able to clip them.
  static const double radialToleranceMeters = 0.75;

  /// Radius around a shared pivot inside which angular prediction
  /// is skipped: both arena arms pivot at the center, and a bot
  /// hugging the pivot should not jump-spam (it also cannot be
  /// meaningfully "swept" at near-zero arm speed).
  static const double quietCoreRadiusMeters = 1;

  /// Wander steering amplitude inside the center band, joystick
  /// units. Small enough to look idle, large enough to unstack
  /// bots seeded identically.
  static const double wanderAmplitude = 0.35;

  /// Wander target offset range from the exact center, meters.
  static const double wanderTargetMeters = 1.5;

  /// Ticks each wander target is held (1.5 s): holds a direction
  /// long enough to actually drift, then re-rolls.
  static const int wanderHoldTicks = 90;

  /// Ticks between jumps (0.25 s): dodges come often, but never
  /// faster than a jump arc can develop.
  static const int jumpCooldownTicks = 15;

  /// Odd multiplier mixing seed and tick into the wander RNG seed
  /// so equal seeds with different ticks diverge deterministically.
  static const int _seedTickMixer = 1000003;

  /// Full circle in radians.
  static const double _tau = math.pi * 2;

  final int _seed;
  final List<_ArmSpec> _arms;
  final double _centerBandMeters;

  int _jumpCooldown = 0;

  @override
  PlayerInputState decide(BotObservation obs) {
    if (_jumpCooldown > 0) _jumpCooldown--;

    final jump = obs.grounded && _jumpCooldown == 0 && _armSweepIncoming(obs);

    final targetX = _wanderTarget(obs.tick);
    final toTarget = targetX - obs.self.x;
    final double moveX;
    if (obs.self.x.abs() > _centerBandMeters) {
      moveX = toTarget.sign * fullMoveInput;
    } else {
      moveX = toTarget.clamp(-wanderAmplitude, wanderAmplitude);
    }
    if (jump) _jumpCooldown = jumpCooldownTicks;
    return PlayerInputState(moveDir: Vector2(moveX, 0), jumpPressed: jump);
  }

  /// True when any nearby arm's linear angle extrapolation (its
  /// angular velocity) puts it on the bot's polar angle within
  /// [dangerTicks] * [PhysicsConsts.fixedDt] seconds, and the bot
  /// stands inside that arm's sweep disc.
  bool _armSweepIncoming(BotObservation obs) {
    for (final hazard in obs.nearbyHazards) {
      final dx = obs.self.x - hazard.x;
      final dy = obs.self.y - hazard.y;
      final arm = _armAt(hazard.x, hazard.y);
      if (arm == null) continue;
      final radius = math.sqrt(dx * dx + dy * dy);
      if (radius > arm.radius + radialToleranceMeters) continue;
      if (radius < quietCoreRadiusMeters) continue;
      final w = hazard.angularVelocity;
      if (w == 0) continue;
      final theta = math.atan2(dy, dx);
      final delta = w > 0
          ? _wrapPositive(theta - hazard.angle)
          : _wrapPositive(hazard.angle - theta);
      final arrivalSeconds = delta / w.abs();
      if (arrivalSeconds <= dangerTicks * PhysicsConsts.fixedDt) {
        return true;
      }
    }
    return false;
  }

  _ArmSpec? _armAt(double x, double y) {
    _ArmSpec? best;
    var bestDistance = double.infinity;
    for (final arm in _arms) {
      final d = (arm.x - x) * (arm.x - x) + (arm.y - y) * (arm.y - y);
      if (d < bestDistance) {
        best = arm;
        bestDistance = d;
      }
    }
    return best;
  }

  double _wanderTarget(int tick) {
    final rng = math.Random(
      (_seed * _seedTickMixer + tick ~/ wanderHoldTicks) & 0x3fffffff,
    );
    return (rng.nextDouble() * 2 - 1) * wanderTargetMeters;
  }

  static double _wrapPositive(double radians) {
    return (radians % _tau + _tau) % _tau;
  }
}
