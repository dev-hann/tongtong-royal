import 'package:app/game/arenas/hill/hill_arena_map.dart';
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

  /// True only on the sample the policy auto-jumps (hill ramps).
  final bool jumpPressed;

  /// Direction a dash impulse should take (hill shove target or
  /// crown center); null when the game has no dash-direction rule
  /// and a dash (if any) simply follows [moveDir].
  final Vector2? dashDir;
}

/// Per-game automatic movement policy (GDD § 3): maps a
/// [SteeringObservation] to a [SteeringDecision]. Pure — no
/// Flutter, no physics engine, no clocks; stateful policies (hill)
/// keep only cooldown counters.
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

/// Hammer Dodge auto-steering (GDD § 3): drift back toward the
/// arena center; idle inside a center band so the player does not
/// fidget on the pivot.
final class HammerSteering implements SteeringPolicy {
  /// Creates the (stateless) survival policy.
  const HammerSteering();

  /// Dead band around the arena center x=0, meters: inside it the
  /// player stops steering (~3 player widths — small against the
  /// 7 m platform, far from the rim where hammer hits launch
  /// players off). Behavior data, same scale as the survival bot's
  /// center band.
  static const double centerBandMeters = 2;

  @override
  SteeringDecision sample(SteeringObservation obs) {
    final x = obs.selfX;
    if (!x.isFinite || x.abs() <= centerBandMeters) {
      return SteeringDecision(moveDir: Vector2.zero());
    }
    return SteeringDecision(
      moveDir: _sanitized(-x.sign, 0),
      dashDir: _sanitized(-x.sign, 0),
    );
  }
}

/// One climbable step (ramp box or the crown platform itself):
/// x-range plus the y of its top surface.
typedef _Step = ({double minX, double maxX, double topY});

/// King of the Hill auto-steering (GDD § 3): walk toward the
/// crown, auto-jump step faces while climbing (mirrors the hill
/// bot's map-data-driven approach); on the crown hold position and
/// aim dashes at the nearest contested occupant, or the crown
/// center when uncontested.
final class HillSteering implements SteeringPolicy {
  /// Extracts the map knowledge this policy needs from [map]:
  /// crown placement and every climbable step face.
  factory HillSteering.fromArenaMap(HillArenaMap map) {
    final crown = map.crownPlatform;
    return HillSteering._(
      map.crownCenter.x,
      map.crownTopY,
      map.crownRadius,
      [
        for (final ramp in map.ramps)
          (
            minX: ramp.center.x - ramp.width / 2,
            maxX: ramp.center.x + ramp.width / 2,
            topY: ramp.center.y + ramp.height / 2,
          ),
        (
          minX: crown.center.x - crown.width / 2,
          maxX: crown.center.x + crown.width / 2,
          topY: crown.center.y + crown.height / 2,
        ),
      ],
    );
  }

  HillSteering._(
    this._crownX,
    this._crownTopY,
    this._crownRadius,
    List<_Step> steps,
  ) : _steps = List.unmodifiable(steps);

  /// Dash/shove reach, meters — same scale as the hill bot's
  /// dash-impulse shove range (~2 m effective).
  static const double shoveRangeMeters = 2;

  /// Dead band around the crown center, meters: the sole occupant
  /// stops fidgeting once this close to center.
  static const double crownHoldBandMeters = 0.4;

  /// Anticipation window for auto-jumping a step face, meters —
  /// two player widths, so the jump starts at the face instead of
  /// a body-length too late.
  static const double lookAheadMeters = 1.2;

  /// Minimum samples between auto-jumps (~0.33 s): climb hops come
  /// quickly but never overlap mid-air. Enforced as a tick
  /// deadline, so skipped samples cannot stall climbing.
  static const int jumpCooldownTicks = 20;

  /// Slack on the feet-height check for "standing on the crown",
  /// meters — tolerates contact jitter without counting floor
  /// standers as occupants.
  static const double onCrownFeetToleranceMeters = 0.15;

  /// Extra x-margin when counting another player as a crown
  /// occupant: one player half-width of forgiveness.
  static const double occupantMarginMeters = 0.3;

  /// Player half-height, meters (GDD: ~1.5 m tall players), used
  /// to derive feet height from the observed body center.
  static const double playerHalfHeightMeters = 0.75;

  /// Grounded approximation threshold, meters per second: a body
  /// whose vertical speed stays below this reads as supported.
  /// Same rationale as the solo driver's twin constant (gravity
  /// adds ~0.17 m/s per tick, resting contact stays near zero) —
  /// duplicated here so steering never depends on the solo layer.
  static const double groundedSpeedEpsilonMeters = 0.5;

  final double _crownX;
  final double _crownTopY;
  final double _crownRadius;
  final List<_Step> _steps;

  int _nextJumpTick = 0;

  @override
  SteeringDecision sample(SteeringObservation obs) {
    if (!obs.selfX.isFinite || !obs.selfY.isFinite) {
      return SteeringDecision(moveDir: Vector2.zero());
    }

    final feetY = obs.selfY - playerHalfHeightMeters;
    if (_isOnCrown(feetY)) {
      return _decideOnCrown(obs);
    }
    return _decideClimbing(obs, feetY);
  }

  SteeringDecision _decideOnCrown(SteeringObservation obs) {
    final target = _nearestOccupant(obs);
    if (target == null) {
      final dx = _crownX - obs.selfX;
      if (dx.abs() <= crownHoldBandMeters || dx == 0) {
        return SteeringDecision(
          moveDir: Vector2.zero(),
          dashDir: _sanitized(dx, 0),
        );
      }
      return SteeringDecision(
        moveDir: _sanitized(dx.sign, 0),
        dashDir: _sanitized(dx.sign, 0),
      );
    }
    final dx = target.x - obs.selfX;
    final dir = dx == 0 ? 0.0 : dx.sign;
    return SteeringDecision(
      moveDir: _sanitized(dir, 0),
      dashDir: _sanitized(dir, 0),
    );
  }

  SteeringDecision _decideClimbing(SteeringObservation obs, double feetY) {
    final dx = _crownX - obs.selfX;
    final moveX = dx == 0 ? 0.0 : dx.sign;
    final grounded = obs.selfVy.abs() < groundedSpeedEpsilonMeters;
    final jump =
        grounded &&
        obs.tick >= _nextJumpTick &&
        _stepAhead(obs.selfX, feetY);
    if (jump) _nextJumpTick = obs.tick + jumpCooldownTicks;
    return SteeringDecision(
      moveDir: _sanitized(moveX, 0),
      jumpPressed: jump,
    );
  }

  /// Nearest on-crown occupant within [shoveRangeMeters], or null.
  SteeringPlayerPosition? _nearestOccupant(SteeringObservation obs) {
    SteeringPlayerPosition? target;
    var best = double.infinity;
    for (final other in obs.nearbyPlayers) {
      final onCrown =
          _isOnCrown(other.y - playerHalfHeightMeters) &&
          (other.x - _crownX).abs() <= _crownRadius + occupantMarginMeters;
      if (!onCrown) continue;
      final d = (other.x - obs.selfX).abs();
      if (d <= shoveRangeMeters && d < best) {
        best = d;
        target = other;
      }
    }
    return target;
  }

  bool _isOnCrown(double feetY) {
    return feetY >= _crownTopY - onCrownFeetToleranceMeters;
  }

  bool _stepAhead(double x, double feetY) {
    return _steps.any(
      (s) =>
          s.topY > feetY && s.maxX > x && s.minX - x <= lookAheadMeters,
    );
  }
}

Vector2 _sanitized(double x, double y) {
  if (!x.isFinite || !y.isFinite) {
    return Vector2.zero();
  }
  return Vector2(x.clamp(-1, 1), y.clamp(-1, 1));
}
