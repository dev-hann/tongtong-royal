import 'package:app/game/controls/steering.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// The single button's verb for one minigame (GDD § 3).
enum GameVerb {
  /// Trap Race, Hammer Dodge: the button jumps.
  jump,

  /// Reserved for future minigames (GDD § 3: the dash verb stays in
  /// the input vocabulary); no MVP game maps the button to a dash.
  dash,
}

/// Minigame id for Trap Race (shared domain `TrapRace.id`).
const String trapRaceId = 'trap_race';

/// Minigame id for Hammer Dodge (shared domain `HammerDodge.id`).
const String hammerDodgeId = 'hammer_dodge';

/// One-button input controller (GDD § 3): owns the physical button
/// state (press/release edges) and combines it with the game's
/// auto-steering policy into the same [PlayerInputState] the
/// simulation has consumed since M1 — protocol, server and bots
/// are unaffected.
///
/// A press fires its edge on exactly one subsequent [sampleFor]
/// call; holding does not repeat. Logic only — no Flutter imports;
/// button widgets drive this through [press]/[release].
final class ActionInputController {
  /// Creates a controller. [policies] overrides or extends the
  /// built-in per-game steering (race and hammer defaults are
  /// stateless; a future map-bound policy would register here).
  ActionInputController({Map<String, SteeringPolicy> policies = const {}})
    : _policies = {
        trapRaceId: const RaceSteering(),
        hammerDodgeId: const HammerSteering(),
        ...policies,
      };

  final Map<String, SteeringPolicy> _policies;
  bool _pressed = false;
  bool _edgeQueued = false;

  /// The button's verb for [gameId]; throws [ArgumentError] for an
  /// unknown id.
  static GameVerb verbFor(String gameId) {
    switch (gameId) {
      case trapRaceId:
      case hammerDodgeId:
        return GameVerb.jump;
      default:
        throw ArgumentError.value(gameId, 'gameId', 'unknown minigame id');
    }
  }

  /// Whether the button is currently held.
  bool get isPressed => _pressed;

  /// Marks the button down; queues one action edge. A second
  /// [press] without an intervening [release] queues nothing.
  void press() {
    if (_pressed) {
      return;
    }
    _pressed = true;
    _edgeQueued = true;
  }

  /// Marks the button up.
  void release() {
    _pressed = false;
  }

  /// Combines the auto-steering decision for [gameId] under [obs]
  /// with the pending button edge (if any):
  ///
  /// - jump games: the edge becomes `jumpPressed`;
  /// - dash games (none in the MVP; [GameVerb.dash] is reserved for
  ///   future minigames): the edge becomes `dashPressed` and the
  ///   move vector becomes the steering policy's dash target
  ///   direction for that one tick (the dash impulse follows the
  ///   move vector, GDD § 3);
  /// - a policy's automatic jump passes through as `jumpPressed`
  ///   regardless of the button.
  PlayerInputState sampleFor(String gameId, SteeringObservation obs) {
    final policy = _policies[gameId];
    if (policy == null) {
      throw ArgumentError.value(
        gameId,
        'gameId',
        'no steering policy registered',
      );
    }
    final decision = policy.sample(obs);
    final edge = _edgeQueued;
    _edgeQueued = false;
    switch (verbFor(gameId)) {
      case GameVerb.jump:
        return PlayerInputState(
          moveDir: decision.moveDir.clone(),
          jumpPressed: edge || decision.jumpPressed,
        );
      case GameVerb.dash:
        return PlayerInputState(
          moveDir: edge
              ? (decision.dashDir ?? decision.moveDir).clone()
              : decision.moveDir.clone(),
          jumpPressed: decision.jumpPressed,
          dashPressed: edge,
        );
    }
  }
}
