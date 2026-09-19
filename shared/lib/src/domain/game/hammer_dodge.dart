import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/placements.dart';
import 'package:tongtong_shared/src/domain/qualification.dart';

/// Hammer-Dodge-specific input beyond the shared [RoundEvents].
///
/// Eliminations travel inside [RoundEvents] as [PlayerEliminated]
/// events, so this input only carries the roster (kept from the v1
/// revival shape; v2 also accepts the roster on [RoundEvents]).
final class HammerDodgeInput {
  /// Creates the input.
  const HammerDodgeInput({this.roster = const {}});

  /// Players present in the round, including players that emitted
  /// no events at all (idle bodies).
  final Set<PlayerId> roster;
}

/// Survival-archetype minigame (hammer-dodge.md), revived from git
/// history (pre-deletion commit `6ef70f3`) and re-fit to the GDD v2
/// qualification era.
///
/// Placements path (v1, kept for the placements-era shell):
/// placement = elimination order reversed, survivors share the best
/// rank at timeout, same-tick eliminations form a shared rank
/// group.
///
/// Qualification path (v2): the round ends the instant the alive
/// count reaches the quota; survivors qualify. A single event that
/// takes the field from above-quota to below-quota (multi-elim on
/// one tick) promotes its victims to qualifiers too (GDD § 7.1) —
/// the quota never silently shrinks. At timeout every survivor
/// qualifies (hammer-dodge.md § Qualification).
final class HammerDodge implements QualificationGame {
  /// Creates the game.
  const HammerDodge();

  @override
  MiniGameId get id => 'hammer_dodge';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Hammer Dodge',
    oneLineRule: 'Last two standing qualify',
    timeoutMs: 60_000,
  );

  @override
  RoundResult resolve(RoundEvents events, [HammerDodgeInput? input]) {
    final eliminationTick = <PlayerId, int>{};
    for (final event in events.events) {
      if (event is PlayerEliminated) {
        // First elimination counts; duplicated elimination events
        // are ignored (idempotent by playerId, game doc § Edge
        // cases).
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

  @override
  QualificationResult resolveQualification(RoundEvents events,
      [Object? input]) {
    final typedInput = switch (input) {
      null => null,
      final HammerDodgeInput hammerInput => hammerInput,
      _ => throw ArgumentError.value(
        input,
        'input',
        'HammerDodge requires HammerDodgeInput',
      ),
    };
    if (events.isFinal) {
      throw ArgumentError.value(
        events.isFinal,
        'isFinal',
        'hammer_dodge only runs as ROUND 2, never as the FINAL',
      );
    }
    final quota = events.quota;
    if (quota == null) {
      throw ArgumentError.notNull('quota');
    }
    if (quota < 1) {
      throw ArgumentError.value(quota, 'quota', 'must be at least 1');
    }

    final eliminationTick = <PlayerId, int>{};
    for (final event in events.events) {
      if (event is PlayerEliminated) {
        eliminationTick.putIfAbsent(event.playerId, () => event.tick);
      }
    }
    final field = <PlayerId>{
      ...events.roster,
      ...eliminationTick.keys,
      ...?typedInput?.roster,
    };
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'roster', 'empty field');
    }

    final alive = field.toSet();
    final eliminated = <PlayerId>[];
    final ticks = eliminationTick.values.toSet().toList()..sort();

    for (final tick in ticks) {
      final victims = [
        for (final entry in eliminationTick.entries)
          if (entry.value == tick) entry.key,
      ];
      alive.removeAll(victims);
      if (alive.length < quota) {
        // Crossing event (GDD § 7.1): the victims qualify alongside
        // the survivors; the quota never silently shrinks.
        return QualificationResult(
          qualified: [...alive, ...victims],
          eliminated: eliminated,
          isFinal: false,
        );
      }
      eliminated.addAll(victims);
      if (alive.length == quota) {
        return QualificationResult(
          qualified: alive.toList(),
          eliminated: eliminated,
          isFinal: false,
        );
      }
    }

    // Timeout: every survivor qualifies (shared) — survival IS the
    // qualification (hammer-dodge.md § Qualification).
    return QualificationResult(
      qualified: alive.toList(),
      eliminated: eliminated,
      isFinal: false,
    );
  }

  /// Best-first rank groups: all survivors share one group, then
  /// eliminated players group by elimination tick, latest tick
  /// first. Players keep first-appearance order within a group.
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
