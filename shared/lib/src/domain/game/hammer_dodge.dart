import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/placements.dart';

/// Hammer-Dodge-specific input [HammerDodge] needs beyond the shared
/// [RoundEvents].
///
/// Eliminations travel inside [RoundEvents] as [PlayerEliminated]
/// events (they are part of the sealed hierarchy), so this input
/// only carries the roster.
final class HammerDodgeInput {
  /// Creates the input.
  const HammerDodgeInput({this.roster = const {}});

  /// Players present in the round, including players that emitted no
  /// events at all (idle bodies, GDD § 7.2). Defaults to empty, in
  /// which case only players mentioned by events are ranked.
  final Set<PlayerId> roster;
}

/// Survival-archetype minigame (GDD § 4.2).
///
/// Placement = elimination order reversed: the first player
/// eliminated places last, survivors (never eliminated) share the
/// best remaining rank equally at timeout (GDD § 7.5), and
/// same-tick eliminations form a shared rank group (GDD § 7.7).
final class HammerDodge implements MiniGame {
  /// Creates the game.
  const HammerDodge();

  @override
  MiniGameId get id => 'hammer_dodge';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Hammer Dodge',
    oneLineRule: 'Last one standing wins',
    timeoutMs: 60_000,
  );

  @override
  RoundResult resolve(RoundEvents events, [HammerDodgeInput? input]) {
    final eliminationTick = <PlayerId, int>{};
    for (final event in events.events) {
      if (event is PlayerEliminated) {
        // First elimination counts; duplicated elimination events
        // are ignored (the simulation destroys the body, so a
        // duplicate would be relay noise).
        eliminationTick.putIfAbsent(event.playerId, () => event.tick);
      }
    }

    final rankedPlayers = <PlayerId>{
      ...?input?.roster,
      ...events.players,
    };

    return RoundResult(
      roundIndex: events.roundIndex,
      minigameId: id,
      placements: Placements.fromRankGroups(
        _rankGroups(rankedPlayers, eliminationTick),
        rankedPlayers.length,
      ),
    );
  }

  /// Best-first rank groups: all survivors share one group (GDD
  /// § 7.5), then eliminated players group by elimination tick,
  /// latest tick first (GDD § 7.7). Players keep first-appearance
  /// order within a group (deterministic ordering).
  static List<List<PlayerId>> _rankGroups(
    Set<PlayerId> rankedPlayers,
    Map<PlayerId, int> eliminationTick,
  ) {
    final survivors = [
      for (final playerId in rankedPlayers)
        if (!eliminationTick.containsKey(playerId)) playerId,
    ];
    final ticks = eliminationTick.values.toSet().toList()..sort();
    return [
      if (survivors.isNotEmpty) survivors,
      for (final tick in ticks.reversed)
        [
          for (final entry in eliminationTick.entries)
            if (entry.value == tick) entry.key,
        ],
    ];
  }
}
