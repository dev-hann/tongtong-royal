import 'package:app/game/player_character.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Stuck-detection displacement threshold, meters.
///
/// Input-magnitude-derived measurement floor, not gameplay tuning:
/// with an active move input a player covers `moveMaxSpeed` (6 m/s),
/// while contact-solver jitter stays around 1e-2 m per tick. 0.25 m
/// per threshold window separates "pushing but blocked" (stuck) from
/// "making progress" for any sustained locomotion attempt, without
/// depending on the threshold duration (architecture doc § 5).
const double stuckDisplacementEpsilonMeters = 0.25;

/// Tracks one racer against the stuck rule (architecture doc § 5):
/// active input with near-zero displacement for the threshold
/// duration means the body must be recovered. Pure state machine —
/// the simulation decides what a trigger does (checkpoint respawn
/// in R1, spawn recovery in the FINAL variant).
final class StuckTracker {
  /// Creates a tracker anchored at [anchor].
  StuckTracker(Vector2 anchor)
    : _reference = anchor.clone(),
      _elapsedSeconds = 0;

  double _elapsedSeconds;
  Vector2 _reference;

  /// Feeds one post-step observation.
  void observe({
    required bool inputActive,
    required Vector2 position,
    required double thresholdSeconds,
  }) {
    if (!inputActive) {
      reset(position);
      return;
    }
    if ((position - _reference).length > stuckDisplacementEpsilonMeters) {
      reset(position);
      return;
    }
    _elapsedSeconds += PhysicsConsts.fixedDt;
  }

  /// Whether the tracked body exceeded [thresholdSeconds] of
  /// near-zero displacement under active input.
  bool triggeredAt(double thresholdSeconds) =>
      _elapsedSeconds >= thresholdSeconds;

  /// Restarts the window at [point].
  void reset(Vector2 point) {
    _reference = point.clone();
    _elapsedSeconds = 0;
  }
}

/// Applies one raw input to [character] (the shared verb pipeline:
/// move always, jump and dash on their press edges).
void applyPlayerInput(PlayerCharacter character, PlayerInputState i) {
  character.applyMove(i.moveDir);
  if (i.jumpPressed) {
    character.jump();
  }
  if (i.dashPressed) {
    character.dash(i.moveDir);
  }
}
