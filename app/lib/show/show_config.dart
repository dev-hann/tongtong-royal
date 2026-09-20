import 'package:app/game/bots/bot_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// GDD v2 § 5 intro countdown, seconds.
const int showIntroSeconds = 3;

/// GDD v2 § 5 QUALIFY_FLASH reveal, seconds.
const int qualifyFlashSeconds = 4;

/// Display name of the FINAL's game banner (narrow Trap Race
/// variant, trap-race.md).
const String showFinalGameName = 'Trap Race Final';

/// Rule line of the FINAL's game banner.
const String showFinalRuleLine = 'First finisher takes the crown';

/// One show seat: the human first, then the bot fill (GDD v2 § 9).
@immutable
final class ShowSeat {
  /// Creates a seat.
  const ShowSeat({
    required this.id,
    required this.nickname,
    this.isBot = false,
  });

  /// Player id of the seat.
  final PlayerId id;

  /// Display nickname.
  final String nickname;

  /// Whether this seat is a bot.
  final bool isBot;
}

/// Configuration of one solo show: the human seat identity, the
/// root [showSeed] the per-round map seeds derive from (GDD v2 § 6),
/// and the fixed seat roster (human + bot fill to 4, GDD v2 § 9).
/// Pure data — no rules here.
final class ShowConfig {
  /// Creates a config.
  const ShowConfig({
    this.humanId = 'solo-player',
    this.humanNickname = 'You',
    this.humanColorIndex = 0,
    this.showSeed = 0,
  });

  /// Player id of the human seat.
  final PlayerId humanId;

  /// Display nickname of the human seat.
  final String humanNickname;

  /// PlayerPalette index of the human seat's persisted color
  /// (GDD v2 § 8.1; injected by the shell wiring).
  final int humanColorIndex;

  /// Root seed of the show; per-round map seeds derive from it via
  /// `ShowSchedule.mapSeedFor` (GDD v2 § 6).
  final int showSeed;

  /// The full seat roster: the human plus bots filling to 4 seats
  /// (GDD v2 § 9).
  List<ShowSeat> buildSeats() => [
    ShowSeat(id: humanId, nickname: humanNickname),
    for (final bot in BotFactory.buildBotRoster(1))
      ShowSeat(id: bot.id, nickname: bot.nickname, isBot: true),
  ];
}
