/// Point awards per placement (GDD § 2, § 7.6).
///
/// Formula: a round with N ranked players gives the rank-R player
/// `N - R + 1` points (1st gets N, last gets 1). Shared ranks score the
/// points of the shared rank itself (GDD § 7.6).
abstract final class Points {
  /// Points for finishing at [rank] in a round with [rankedPlayerCount]
  /// ranked players.
  static int forPlacements(int rankedPlayerCount, int rank) {
    _validateRank(rankedPlayerCount, rank);
    return rankedPlayerCount - rank + 1;
  }

  /// Points for each player sharing [sharedRank] in a round with
  /// [playersInRound] players (GDD § 7.5, § 7.6).
  static int forSharedRank(int playersInRound, int sharedRank) {
    _validateRank(playersInRound, sharedRank);
    return playersInRound - sharedRank + 1;
  }

  static void _validateRank(int playerCount, int rank) {
    if (playerCount < 1) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'must be at least 1',
      );
    }
    if (rank < 1 || rank > playerCount) {
      throw ArgumentError.value(
        rank,
        'rank',
        'must be within 1..$playerCount',
      );
    }
  }
}
