import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/placements.dart';

/// King-of-the-Hill-specific input [KingOfTheHill] needs beyond the
/// shared [RoundEvents].
///
/// Hold times travel inside [RoundEvents] as [HoldTimeSample] events
/// (they are part of the sealed hierarchy, unlike race progress
/// samples), so this input only carries the roster.
final class KingOfTheHillInput {
  /// Creates the input.
  const KingOfTheHillInput({this.roster = const {}});

  /// Players present in the round, including players that emitted no
  /// events at all (idle bodies, GDD § 7.2). Defaults to empty, in
  /// which case only players mentioned by events are ranked.
  final Set<PlayerId> roster;
}

/// Occupancy-archetype minigame (GDD § 4.3).
///
/// Placement = hold-time ranking at the 75 s timeout, descending;
/// equal hold times share a rank (GDD § 2.1 conventions). This
/// resolver is a dumb ranker: the contested rule (two or more
/// players on the crown zone score nothing, GDD § 4.3) is judged by
/// the host simulation, which only accumulates and samples hold
/// time while a player is the sole occupant. Players with no (or
/// zero) hold time rank last with 0 s, sharing that rank.
final class KingOfTheHill implements MiniGame {
  /// Creates the game.
  const KingOfTheHill();

  @override
  MiniGameId get id => 'king_of_the_hill';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'King of the Hill',
    oneLineRule: 'Hold the crown the longest',
    timeoutMs: 75_000,
  );

  @override
  RoundResult resolve(RoundEvents events, [KingOfTheHillInput? input]) {
    // Last sample per player wins (pattern parity with the race's
    // ProgressSample handling).
    final lastSample = <PlayerId, HoldTimeSample>{};
    for (final event in events.events) {
      if (event is HoldTimeSample) {
        lastSample[event.playerId] = event;
      }
    }

    final rankedPlayers = <PlayerId>{
      ...?input?.roster,
      ...events.players,
    };

    final holdSeconds = <PlayerId, double>{
      for (final playerId in rankedPlayers)
        playerId: lastSample[playerId]?.seconds ?? 0,
    };

    return RoundResult(
      roundIndex: events.roundIndex,
      minigameId: id,
      placements: Placements.fromRankGroups(
        _rankGroups(holdSeconds),
        rankedPlayers.length,
      ),
    );
  }

  /// Groups players by hold time, best (most seconds) first; ties
  /// share a group and keep first-appearance order within it
  /// (deterministic ordering, pattern parity with `RaceRules`).
  static List<List<PlayerId>> _rankGroups(
    Map<PlayerId, double> holdSeconds,
  ) {
    final keys = holdSeconds.keys.toList();
    final indexed = [
      for (var i = 0; i < keys.length; i++) (i, keys[i]),
    ]..sort((a, b) {
      final secondsDiff = holdSeconds[b.$2]!.compareTo(holdSeconds[a.$2]!);
      if (secondsDiff != 0) return secondsDiff;
      return a.$1.compareTo(b.$1);
    });
    final ordered = [for (final entry in indexed) entry.$2];

    final groups = <List<PlayerId>>[];
    var i = 0;
    while (i < ordered.length) {
      var groupEnd = i + 1;
      while (
          groupEnd < ordered.length &&
          holdSeconds[ordered[groupEnd]] == holdSeconds[ordered[i]]) {
        groupEnd++;
      }
      groups.add(ordered.sublist(i, groupEnd));
      i = groupEnd;
    }
    return groups;
  }
}
