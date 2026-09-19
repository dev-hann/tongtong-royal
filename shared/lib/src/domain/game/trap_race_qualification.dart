import 'package:tongtong_shared/src/domain/game/trap_race.dart';
import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/qualification.dart';
import 'package:tongtong_shared/src/domain/race_rules.dart';

/// GDD v2 qualification rules for TrapRace (trap-race.md
/// § Qualification). Lives beside `TrapRace` in its own file only to
/// respect the 300-line file limit (docs/05).
abstract final class TrapRaceQualification {
  /// Resolves a TrapRace round to a qualification verdict.
  ///
  /// R1 mode: rank by finish tick then forward progress (R1 falls
  /// respawn — they never eliminate) and fill the quota by rank
  /// groups; a group straddling the quota boundary enters whole
  /// (GDD § 7.1 same-tick slot-holding).
  ///
  /// FINAL mode: no respawn — falls and eliminations both remove a
  /// player. The round ends at the first crown-deciding instant: a
  /// finish (the finish sensor order at that tick is final, so
  /// same-tick fallers lose and same-tick finishers share), the
  /// elimination leaving one alive (survival crown), or an
  /// elimination group emptying the field (shared crown, GDD
  /// § 7.2). Timeout ranks survivors by progress; the leader group
  /// crowns, shared on an exact tie.
  static QualificationResult resolve(RoundEvents events, Object? input) {
    final typedInput = switch (input) {
      null => null,
      final TrapRaceInput raceInput => raceInput,
      _ => throw ArgumentError.value(
        input,
        'input',
        'TrapRace requires TrapRaceInput',
      ),
    };
    final quota = events.quota;
    if (quota == null) {
      throw ArgumentError.notNull('quota');
    }
    if (quota < 1) {
      throw ArgumentError.value(quota, 'quota', 'must be at least 1');
    }

    final finishTick = <PlayerId, int>{};
    for (final event in events.events) {
      if (event is PlayerFinished) {
        finishTick.putIfAbsent(event.playerId, () => event.tick);
      }
    }
    final lastSample = <PlayerId, ProgressSample>{};
    for (final sample in typedInput?.samples ?? const <ProgressSample>[]) {
      lastSample[sample.playerId] = sample;
    }
    final field = <PlayerId>{
      ...events.roster,
      ...events.players,
      ...lastSample.keys,
      ...?typedInput?.roster,
    };
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'roster', 'empty field');
    }
    if (events.events.isEmpty && lastSample.isEmpty) {
      throw ArgumentError.value(
        events,
        'events',
        'round produced no observable data',
      );
    }

    return events.isFinal
        ? _resolveFinal(events, field, lastSample)
        : _resolveRound1(quota, field, finishTick, lastSample);
  }

  static QualificationResult _resolveRound1(
    int quota,
    Set<PlayerId> field,
    Map<PlayerId, int> finishTick,
    Map<PlayerId, ProgressSample> lastSample,
  ) {
    final groups = RaceRules.rankOnTimeout([
      for (final playerId in field)
        (
          id: playerId,
          finished: finishTick.containsKey(playerId),
          finishTick: finishTick[playerId] ?? 0,
          progressDistance: lastSample[playerId]?.distance ?? 0,
        ),
    ]);

    final qualified = <PlayerId>[];
    var groupIndex = 0;
    while (groupIndex < groups.length && qualified.length < quota) {
      qualified.addAll(groups[groupIndex]);
      groupIndex++;
    }
    final eliminated = [
      for (; groupIndex < groups.length; groupIndex++)
        ...groups[groupIndex],
    ];
    return QualificationResult(
      qualified: qualified,
      eliminated: eliminated,
      isFinal: false,
    );
  }

  static QualificationResult _resolveFinal(
    RoundEvents events,
    Set<PlayerId> field,
    Map<PlayerId, ProgressSample> lastSample,
  ) {
    final timed = <({int order, int tick, RoundEvent event})>[
      for (var i = 0; i < events.events.length; i++)
        switch (events.events[i]) {
          final PlayerFinished e => (order: i, tick: e.tick, event: e),
          final PlayerFell e => (order: i, tick: e.tick, event: e),
          final PlayerEliminated e => (order: i, tick: e.tick, event: e),
          _ => throw StateError('unreachable: sealed hierarchy'),
        },
    ]..sort((a, b) {
      final diff = a.tick.compareTo(b.tick);
      return diff != 0 ? diff : a.order.compareTo(b.order);
    });

    final alive = field.toSet();
    final decided = <PlayerId>{};
    final eliminated = <PlayerId>[];

    var i = 0;
    while (i < timed.length) {
      var groupEnd = i;
      while (groupEnd < timed.length && timed[groupEnd].tick ==
          timed[i].tick) {
        groupEnd++;
      }
      final tickFinishers = <PlayerId>[];
      final tickFallers = <PlayerId>[];
      for (final timedEvent in timed.sublist(i, groupEnd)) {
        switch (timedEvent.event) {
          case PlayerFinished(:final playerId):
            if (decided.add(playerId)) tickFinishers.add(playerId);
          case PlayerFell(:final playerId):
            if (decided.add(playerId)) tickFallers.add(playerId);
          case PlayerEliminated(:final playerId):
            if (decided.add(playerId)) tickFallers.add(playerId);
          case HoldTimeSample():
            break;
        }
      }

      if (tickFinishers.isNotEmpty) {
        // End instant: the finish sensor order at this tick is final.
        eliminated.addAll(tickFallers);
        alive
          ..removeAll(tickFallers)
          ..removeAll(tickFinishers);
        eliminated.addAll(alive);
        return _finalResult(tickFinishers, eliminated);
      }

      alive.removeAll(tickFallers);
      eliminated.addAll(tickFallers);
      if (alive.isEmpty) {
        // Every remaining player fell on this tick: shared crown —
        // the victims are champions, not eliminated (GDD § 7.2).
        eliminated.removeRange(
          eliminated.length - tickFallers.length,
          eliminated.length,
        );
        return _finalResult(tickFallers, eliminated);
      }
      if (alive.length == 1) {
        return _finalResult([alive.single], eliminated);
      }
      i = groupEnd;
    }

    // Timeout: survivors rank by forward progress; the leader group
    // crowns (shared on exact tie).
    final groups = RaceRules.rankOnTimeout([
      for (final playerId in alive)
        (
          id: playerId,
          finished: false,
          finishTick: 0,
          progressDistance: lastSample[playerId]?.distance ?? 0,
        ),
    ]);
    final champions = groups.removeAt(0);
    eliminated.addAll([for (final group in groups) ...group]);
    return _finalResult(champions, eliminated);
  }

  static QualificationResult _finalResult(
    List<PlayerId> champions,
    List<PlayerId> eliminated,
  ) => QualificationResult(
    qualified: champions,
    eliminated: eliminated,
    isFinal: true,
    champions: champions,
  );
}
