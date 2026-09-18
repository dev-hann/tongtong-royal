import 'package:meta/meta.dart';

/// Player identity used across domain models.
typedef PlayerId = String;

/// Minigame identity used across domain models.
typedef MiniGameId = String;

/// A single player's standing in one round or in the final ranking.
@immutable
final class Placement {
  /// Creates a placement for [playerId] at [rank] worth [points].
  const Placement({
    required this.playerId,
    required this.rank,
    required this.points,
  });

  /// The player this placement belongs to.
  final PlayerId playerId;

  /// The standing, 1-based. Shared ranks repeat (two 1sts -> next is 3).
  final int rank;

  /// Points awarded for this placement.
  final int points;

  @override
  bool operator ==(Object other) =>
      other is Placement &&
      other.playerId == playerId &&
      other.rank == rank &&
      other.points == points;

  @override
  int get hashCode => Object.hash(playerId, rank, points);

  @override
  String toString() =>
      'Placement($playerId, rank: $rank, points: $points)';
}

/// Resolved standings for one finished round.
@immutable
final class RoundResult {
  /// Creates a result for round [roundIndex] of minigame [minigameId].
  const RoundResult({
    required this.roundIndex,
    required this.minigameId,
    required this.placements,
  });

  /// Zero-based index of the round inside the match.
  final int roundIndex;

  /// The minigame that produced this result.
  final MiniGameId minigameId;

  /// Standings of this round, best first.
  final List<Placement> placements;
}

/// Final standings of a whole match after all rounds and tie-breaks.
@immutable
final class MatchResult {
  /// Creates a match result from [finalRankings].
  const MatchResult({required this.finalRankings});

  /// Final standings, best first. Shared ranks repeat.
  final List<Placement> finalRankings;
}
