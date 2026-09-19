// Vector2 is the repo-wide math type (same seam as the bot brains);
// no physics-engine behavior crosses it — steering only reasons over
// poses and map data.
import 'package:forge2d/forge2d.dart' show Vector2;

/// Position of one nearby player body, world meters.
typedef SteeringPlayerPosition = ({double x, double y});

/// What the auto-steering policy may see of the local player's
/// world (GDD § 3: fully automatic movement). Mirrors the bot
/// observation contract — own pose + tick + nearby players only,
/// no omniscience. Map knowledge is injected per-policy.
final class SteeringObservation {
  /// Creates an observation; [nearbyPlayers] defaults to empty.
  const SteeringObservation({
    required this.tick,
    required this.selfX,
    required this.selfY,
    this.selfVx = 0,
    this.selfVy = 0,
    this.nearbyPlayers = const [],
  });

  /// Current sample index (drives cooldown bookkeeping).
  final int tick;

  /// Own body center, meters.
  final double selfX;

  /// Own body center, meters.
  final double selfY;

  /// Own linear velocity, meters per second.
  final double selfVx;

  /// Own linear velocity, meters per second.
  final double selfVy;

  /// Other players within the awareness radius of the self pose.
  final List<SteeringPlayerPosition> nearbyPlayers;
}

/// One auto-steering decision: where to walk, whether the game
/// itself jumps this tick, and where a dash impulse would aim.
final class SteeringDecision {
  /// Creates a decision; [moveDir] must already be sanitized.
  const SteeringDecision({
    required this.moveDir,
    this.jumpPressed = false,
    this.dashDir,
  });

  /// Sanitized movement vector (components within [-1, 1]).
  final Vector2 moveDir;

  /// True only on the sample the policy itself auto-jumps.
  final bool jumpPressed;

  /// Direction a dash impulse would aim at, when a game's dash rule
  /// needs an explicit target; null when a dash (if any) simply
  /// follows [moveDir]. No MVP game uses it.
  final Vector2? dashDir;
}

/// Per-game automatic movement policy (GDD § 3): maps a
/// [SteeringObservation] to a [SteeringDecision]. Pure — no
/// Flutter, no physics engine, no clocks.
// One-method seam is deliberate: it mirrors BotBrain.
// ignore: one_member_abstracts
abstract interface class SteeringPolicy {
  /// Returns the automatic movement decision for [obs].
  SteeringDecision sample(SteeringObservation obs);
}

/// Trap Race auto-steering (GDD § 3): constant rightward auto-run.
/// The player only times jumps.
final class RaceSteering implements SteeringPolicy {
  /// Creates the (stateless) race policy.
  const RaceSteering();

  @override
  SteeringDecision sample(SteeringObservation obs) {
    return SteeringDecision(
      moveDir: _sanitized(1, 0),
      dashDir: _sanitized(1, 0),
    );
  }
}

Vector2 _sanitized(double x, double y) {
  if (!x.isFinite || !y.isFinite) {
    return Vector2.zero();
  }
  return Vector2(x.clamp(-1, 1), y.clamp(-1, 1));
}
