import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/bots/survival_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One bot's seat identity (GDD § 9.1).
typedef BotIdentity = ({PlayerId id, String nickname});

/// Builds bot brains per minigame and bot seat rosters per the
/// GDD § 9.1 fill policy. Bots run host-side only; nothing here
/// crosses the wire.
final class BotFactory {
  /// Minigame id for Trap Race (shared domain `TrapRace.id`).
  static const String trapRaceId = 'trap_race';

  /// Minigame id for Hammer Dodge (shared domain `HammerDodge.id`).
  static const String hammerDodgeId = 'hammer_dodge';

  /// Size of the bot identity pool: `bot-1`..`bot-3` (GDD § 9.1).
  static const int maxBots = 3;

  /// Default seat count a room fills to (GDD: 2-4 players).
  static const int defaultSeatTarget = 4;

  static const String _idPrefix = 'bot-';
  static const String _nicknamePrefix = 'BOT ';

  /// Returns the archetype brain for [id], seeded with [seed] and
  /// bound to [map]. Throws [ArgumentError] for an unknown id or a
  /// map whose type does not match the minigame.
  static BotBrain forGame(
    MiniGameId id, {
    required int seed,
    required Object map,
  }) {
    switch (id) {
      case trapRaceId:
        if (map is! CourseMap) {
          throw ArgumentError.value(
            map,
            'map',
            'trap_race requires a CourseMap',
          );
        }
        return RaceBot.fromCourseMap(map);
      case hammerDodgeId:
        if (map is! HammerArenaMap) {
          throw ArgumentError.value(
            map,
            'map',
            'hammer_dodge requires a HammerArenaMap',
          );
        }
        return SurvivalBot.fromArenaMap(map, seed: seed);
      default:
        throw ArgumentError.value(id, 'id', 'unknown minigame id');
    }
  }

  /// Bot seats filling a room with [humanCount] humans up to
  /// [seatTarget] total (GDD § 9.1: bots fill seats, never
  /// displace humans; ids `bot-1`.., nicknames `BOT 1`..). The
  /// roster is capped at [maxBots] — the size of the identity
  /// pool — so a (theoretical) zero-human room gets three bots,
  /// not four.
  static List<BotIdentity> buildBotRoster(
    int humanCount, {
    int seatTarget = defaultSeatTarget,
  }) {
    if (seatTarget < 1) {
      throw ArgumentError.value(seatTarget, 'seatTarget', 'must be >= 1');
    }
    if (humanCount < 0 || humanCount > seatTarget) {
      throw ArgumentError.value(
        humanCount,
        'humanCount',
        'must be within 0..seatTarget',
      );
    }
    final botCount = math.min(seatTarget - humanCount, maxBots);
    return [
      for (var i = 1; i <= botCount; i++)
        (id: '$_idPrefix$i', nickname: '$_nicknamePrefix$i'),
    ];
  }
}
