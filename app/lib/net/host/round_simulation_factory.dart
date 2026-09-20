import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/round_simulation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Builds the round simulation for a minigame/seed pair (architecture
/// doc § 3: physics construction lives in `app/game`, driven by map
/// data + the round seed).
typedef RoundSimulationFactory = RoundSimulation Function(
  MiniGameId minigameId,
  int mapSeed,
  Iterable<PlayerId> roster,
);

/// Default factory: dispatches each registered minigame id to its
/// built-in map variant for [mapSeed]. Unknown ids are rejected —
/// a new course variant is map data, a new archetype adds one case.
RoundSimulation defaultRoundSimulationFactory(
  MiniGameId minigameId,
  int mapSeed,
  Iterable<PlayerId> roster,
) => switch (minigameId) {
  'trap_race' => RaceSimulation(
    map: CourseMap.trapRace(mapSeed),
    playerIds: roster,
  ),
  'trap_race_final' => RaceSimulation(
    map: CourseMap.trapRaceFinal(mapSeed, roster.length),
    playerIds: roster,
    variant: RaceVariant.finalRound,
  ),
  'hammer_dodge' => HammerSimulation(
    map: HammerArenaMap.hammerArena(mapSeed),
    playerIds: roster,
    // ROUND 2 quota travels with the show schedule (GDD § 4), not
    // the game: read it from the standard schedule's slot.
    quota: ShowSchedule.standard.slotFor(2).quota,
  ),
  _ => throw ArgumentError.value(
    minigameId,
    'minigameId',
    'no simulation binding',
  ),
};
