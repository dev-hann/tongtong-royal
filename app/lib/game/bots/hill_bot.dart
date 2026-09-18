import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/bots/bot_brain.dart';
// Vector2 is the repo-wide math type (same seam as
// touch_input_source.dart); no physics-engine types cross it.
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

/// One climbable step (ramp box or the crown platform itself):
/// x-range plus the y of its top surface.
typedef _Step = ({double minX, double maxX, double topY});

/// Heuristic King of the Hill player (GDD § 9.2, basic
/// difficulty): off the crown it walks toward the crown center and
/// jumps at step faces (ramps / crown platform edge); alone on the
/// crown it holds position; with another occupant on the crown it
/// dashes at the nearest one to shove them off.
final class HillBot implements BotBrain {
  /// Extracts the map knowledge this brain needs from [map]:
  /// crown placement and every climbable step face. The policy is
  /// fully deterministic, so there is no seed to take.
  factory HillBot.fromArenaMap(HillArenaMap map) {
    final crown = map.crownPlatform;
    return HillBot._(map.crownCenter.x, map.crownTopY, map.crownRadius, [
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
    ]);
  }

  HillBot._(this._crownX, this._crownTopY, this._crownRadius, List<_Step> steps)
    : _steps = List.unmodifiable(steps);

  /// Dash reach, meters: [PhysicsConsts.dashImpulse] on a ~65 kg
  /// player is a ~4 m/s burst, ~2 m of effective shove reach.
  static const double shoveRangeMeters = 2;

  /// Dead band around the crown center, meters: the sole occupant
  /// stops fidgeting once this close to center.
  static const double crownHoldBandMeters = 0.4;

  /// Anticipation window for jumping at a step face, meters —
  /// two player widths, so the jump starts at the face instead of
  /// a body-length too late.
  static const double rampJumpLookAheadMeters = 1.2;

  /// Ticks between dashes (0.75 s): a shove burst, not a stream of
  /// [PhysicsConsts.dashImpulse] presses.
  static const int dashCooldownTicks = 45;

  /// Ticks between jumps (~0.33 s): climb hops come quickly but
  /// never overlap mid-air.
  static const int jumpCooldownTicks = 20;

  /// Slack on the feet-height check for "standing on the crown",
  /// meters — tolerates contact jitter without counting floor
  /// standers as occupants.
  static const double onCrownFeetToleranceMeters = 0.15;

  /// Extra x-margin when counting another player as a crown
  /// occupant: one player half-width of forgiveness.
  static const double occupantMarginMeters = 0.3;

  /// Player half-height, meters (GDD: ~1.5 m tall players). Used to
  /// derive feet height from the observed body center.
  static const double playerHalfHeightMeters = 0.75;

  final double _crownX;
  final double _crownTopY;
  final double _crownRadius;
  final List<_Step> _steps;

  int _jumpCooldown = 0;
  int _dashCooldown = 0;

  @override
  PlayerInputState decide(BotObservation obs) {
    if (_jumpCooldown > 0) _jumpCooldown--;
    if (_dashCooldown > 0) _dashCooldown--;

    final feetY = obs.self.y - playerHalfHeightMeters;
    if (_isOnCrown(feetY)) {
      return _decideOnCrown(obs);
    }
    return _decideClimbing(obs, feetY);
  }

  PlayerInputState _decideOnCrown(BotObservation obs) {
    BotPose? target;
    var bestDistance = double.infinity;
    for (final other in obs.nearbyPlayers) {
      final onCrown =
          _isOnCrown(other.y - playerHalfHeightMeters) &&
          (other.x - _crownX).abs() <= _crownRadius + occupantMarginMeters;
      if (!onCrown) continue;
      final d = (other.x - obs.self.x).abs();
      if (d < bestDistance) {
        bestDistance = d;
        target = other;
      }
    }
    if (target == null) {
      final dx = _crownX - obs.self.x;
      if (dx.abs() <= crownHoldBandMeters || dx == 0) {
        return PlayerInputState(moveDir: Vector2.zero());
      }
      return PlayerInputState(moveDir: Vector2(dx.sign * fullMoveInput, 0));
    }
    final dash = bestDistance <= shoveRangeMeters && _dashCooldown == 0;
    if (dash) _dashCooldown = dashCooldownTicks;
    return PlayerInputState(
      moveDir: Vector2((target.x - obs.self.x).sign * fullMoveInput, 0),
      dashPressed: dash,
    );
  }

  PlayerInputState _decideClimbing(BotObservation obs, double feetY) {
    final dx = _crownX - obs.self.x;
    final moveX = dx == 0 ? 0.0 : dx.sign * fullMoveInput;
    final jump =
        obs.grounded && _jumpCooldown == 0 && _stepAhead(obs.self.x, feetY);
    if (jump) _jumpCooldown = jumpCooldownTicks;
    return PlayerInputState(moveDir: Vector2(moveX, 0), jumpPressed: jump);
  }

  bool _isOnCrown(double feetY) {
    return feetY >= _crownTopY - onCrownFeetToleranceMeters;
  }

  bool _stepAhead(double x, double feetY) {
    return _steps.any(
      (s) =>
          s.topY > feetY && s.maxX > x && s.minX - x <= rampJumpLookAheadMeters,
    );
  }
}
