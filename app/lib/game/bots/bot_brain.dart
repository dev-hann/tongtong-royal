import 'package:tongtong_shared/tongtong_shared.dart';

/// Perceived pose of one player body (position + linear velocity),
/// in world meters / meters per second.
typedef BotPose = ({double x, double y, double vx, double vy});

/// Perceived state of one rotating hazard arm: pivot position,
/// current angle in radians from +x, angular velocity in rad/s.
typedef BotHazard = ({
  double x,
  double y,
  double angle,
  double angularVelocity,
});

/// Full single-axis joystick deflection (unit input).
const double fullMoveInput = 1;

/// How far a bot perceives the world, meters. Sized to the course
/// scale (a race course spans tens of meters; 8 m covers a standing
/// player's whole forward view). Hosts should
/// pre-filter [BotObservation.nearbyPlayers] and
/// [BotObservation.nearbyHazards] to this radius around the bot;
/// brains defensively re-filter as well (GDD 9.2: contact-level
/// awareness of nearby bodies only — no omniscience).
const double awarenessRadius = 8;

/// A bot player's decision brain: pure mapping from what the bot
/// may perceive ([BotObservation]) to one tick of player input
/// (GDD § 9.2, difficulty: basic). Implementations must stay free
/// of physics-engine types — physics stays in the simulations; the
/// brain only reasons over poses and map data.
///
/// The single-method contract is deliberate: one decision per
/// tick is the whole seam (GDD § 9.2), so the one-member-abstract
/// lint is suppressed.
// ignore: one_member_abstracts
abstract interface class BotBrain {
  /// Returns the input this bot presses on tick [BotObservation.tick].
  PlayerInputState decide(BotObservation obs);
}

/// What a bot may see (GDD 9.2): own pose + tick + nearby bodies
/// only. Map knowledge is injected per-archetype in the brain
/// constructors, not carried here.
final class BotObservation {
  /// Creates an observation; nearby lists default to empty.
  const BotObservation({
    required this.tick,
    required this.self,
    this.grounded = true,
    this.nearbyPlayers = const [],
    this.nearbyHazards = const [],
  });

  /// Current simulation tick.
  final int tick;

  /// The bot's own pose.
  final BotPose self;

  /// True when a ground-like contact supports the bot this tick.
  final bool grounded;

  /// Other players within [awarenessRadius] of the bot.
  final List<BotPose> nearbyPlayers;

  /// Hazard arms within [awarenessRadius] of the bot. Order should
  /// follow the map's hammer list so brains can pair an arm's live
  /// angle with its map spec (radius) by pivot.
  final List<BotHazard> nearbyHazards;
}
