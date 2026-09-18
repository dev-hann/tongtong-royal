import 'package:tongtong_shared/src/domain/models.dart';

/// Final standings from round results (GDD § 2.1, § 7.2).
abstract final class Rankings {
  /// Computes final rankings from [rounds]:
  /// 1. Sum each player's points over all rounds.
  /// 2. [forfeited] players are excluded entirely (GDD § 7.2).
  /// 3. Points ties are broken by comparing round placements from the
  ///    last round backwards (better placement wins; absent player counts
  ///    as worst possible placement in that round).
  /// 4. Still tied players share the rank; the next rank is skipped.
  static MatchResult finalRanking(
    List<RoundResult> rounds,
    Set<PlayerId> forfeited,
  ) {
    final orderedRounds = [...rounds]..sort(
      (a, b) => a.roundIndex.compareTo(b.roundIndex),
    );
    final placementByRound = <RoundResult, Map<PlayerId, int>>{
      for (final round in orderedRounds)
        round: {
          for (final placement in round.placements)
            placement.playerId: placement.rank,
        },
    };

    final points = <PlayerId, int>{};
    for (final round in orderedRounds) {
      for (final placement in round.placements) {
        if (forfeited.contains(placement.playerId)) continue;
        points.update(
          placement.playerId,
          (value) => value + placement.points,
          ifAbsent: () => placement.points,
        );
      }
    }

    int placementOf(RoundResult round, PlayerId player) =>
        placementByRound[round]?[player] ?? round.placements.length + 1;

    int compare(PlayerId a, PlayerId b) {
      final pointsDiff = (points[b] ?? 0) - (points[a] ?? 0);
      if (pointsDiff != 0) return pointsDiff;
      for (var i = orderedRounds.length - 1; i >= 0; i--) {
        final round = orderedRounds[i];
        final placementDiff = placementOf(round, a) - placementOf(round, b);
        if (placementDiff != 0) return placementDiff;
      }
      return 0;
    }

    final players = points.keys.toList()..sort(compare);

    final rankings = <Placement>[];
    var slot = 1;
    var i = 0;
    while (i < players.length) {
      var groupEnd = i + 1;
      while (groupEnd < players.length &&
          compare(players[i], players[groupEnd]) == 0) {
        groupEnd++;
      }
      for (var j = i; j < groupEnd; j++) {
        rankings.add(
          Placement(
            playerId: players[j],
            rank: slot,
            points: points[players[j]] ?? 0,
          ),
        );
      }
      slot += groupEnd - i;
      i = groupEnd;
    }
    return MatchResult(finalRankings: rankings);
  }
}
