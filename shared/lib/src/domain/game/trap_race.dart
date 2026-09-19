import 'package:tongtong_shared/src/domain/game/trap_race_qualification.dart';
import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/placements.dart';
import 'package:tongtong_shared/src/domain/qualification.dart';
import 'package:tongtong_shared/src/domain/race_rules.dart';

/// A forward-progress distance sample of one racer (GDD § 7.4).
///
/// The [RoundEvent] hierarchy is sealed, so progress samples cannot join
/// it; hosts pass them next to the round events via [TrapRaceInput].
final class ProgressSample {
  /// Creates the sample.
  const ProgressSample({
    required this.tick,
    required this.playerId,
    required this.distance,
  });

  /// Simulation tick of the sample.
  final int tick;

  /// The sampled player.
  final PlayerId playerId;

  /// Forward progress distance along the course at sampling time.
  final double distance;
}

/// Race-specific input [TrapRace] needs beyond the shared [RoundEvents].
final class TrapRaceInput {
  /// Creates the input.
  const TrapRaceInput({this.roster = const {}, this.samples = const []});

  /// Players present in the round, including players that emitted no
  /// events at all (idle bodies, GDD § 7.2). Defaults to empty, in which
  /// case only players mentioned by events or samples are ranked.
  final Set<PlayerId> roster;

  /// Forward-progress samples in emission order. For each player only the
  /// last sample counts (GDD § 7.4).
  final List<ProgressSample> samples;
}

/// Race-archetype minigame (GDD § 4.1).
///
/// Finishers place by finish tick, same tick means a shared rank
/// (GDD § 7.6); unfinished players place below all finishers by last
/// progress distance, furthest first (GDD § 7.4). Falls only respawn,
/// they never affect ranking.
final class TrapRace implements QualificationGame {
  /// Creates the game.
  const TrapRace();

  @override
  MiniGameId get id => 'trap_race';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Trap Race',
    oneLineRule: 'First to the finish line',
    timeoutMs: 90_000,
  );

  @override
  RoundResult resolve(RoundEvents events, [TrapRaceInput? input]) {
    final finishTick = <PlayerId, int>{};
    for (final event in events.events) {
      if (event is PlayerFinished) {
        // First finish counts; duplicated finish events are ignored.
        finishTick.putIfAbsent(event.playerId, () => event.tick);
      }
    }

    final lastSample = <PlayerId, ProgressSample>{};
    for (final sample in input?.samples ?? const <ProgressSample>[]) {
      lastSample[sample.playerId] = sample;
    }

    final rankedPlayers = <PlayerId>{
      ...?input?.roster,
      ...events.players,
      ...lastSample.keys,
    };

    final entries = [
      for (final playerId in rankedPlayers)
        (
          id: playerId,
          finished: finishTick.containsKey(playerId),
          finishTick: finishTick[playerId] ?? 0,
          progressDistance: lastSample[playerId]?.distance ?? 0,
        ),
    ];

    return RoundResult(
      roundIndex: events.roundIndex,
      minigameId: id,
      placements: Placements.fromRankGroups(
        RaceRules.rankOnTimeout(entries),
        rankedPlayers.length,
      ),
    );
  }

  @override
  QualificationResult resolveQualification(RoundEvents events,
      [Object? input]) => TrapRaceQualification.resolve(events, input);
}
