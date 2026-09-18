import 'package:flutter/foundation.dart';

/// View model for one HUD score-strip entry (dumb data).
@immutable
class ScoreEntry {
  /// Creates a score entry.
  const ScoreEntry({required this.playerId, required this.points});

  /// The player this score belongs to.
  final String playerId;

  /// Cumulative points of the player.
  final int points;
}
