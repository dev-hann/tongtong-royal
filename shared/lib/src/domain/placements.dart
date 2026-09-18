import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/points.dart';

/// Builds round placements from rank groups (GDD § 7.6, § 7.5, § 7.7).
///
/// Each entry of the rank-group list is a group of players sharing one
/// rank, ordered best to worst. Group i gets rank
/// (number of players in earlier groups) + 1; every member scores the
/// points of that rank for a round with the given player count.
abstract final class Placements {
  /// Converts [rankGroups] into a flat placement list for a round with
  /// [playersInRound] players.
  static List<Placement> fromRankGroups(
    List<List<PlayerId>> rankGroups,
    int playersInRound,
  ) {
    if (playersInRound < 1) {
      throw ArgumentError.value(
        playersInRound,
        'playersInRound',
        'must be at least 1',
      );
    }
    final rankedCount = rankGroups.fold<int>(
      0,
      (sum, group) => sum + group.length,
    );
    if (rankedCount > playersInRound) {
      throw ArgumentError.value(
        rankGroups,
        'rankGroups',
        'ranked players ($rankedCount) exceed round players '
            '($playersInRound)',
      );
    }

    final placements = <Placement>[];
    var rank = 1;
    for (final group in rankGroups) {
      if (group.isEmpty) {
        throw ArgumentError.value(group, 'rankGroup', 'must not be empty');
      }
      final points = Points.forSharedRank(playersInRound, rank);
      for (final playerId in group) {
        placements.add(
          Placement(playerId: playerId, rank: rank, points: points),
        );
      }
      rank += group.length;
    }
    return placements;
  }
}
