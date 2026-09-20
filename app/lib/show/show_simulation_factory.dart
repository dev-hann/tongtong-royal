import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/round_simulation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One built round: the simulation plus the map data it was built
/// from (renderers and bot observations need the map alongside).
typedef ShowSimulationBundle = ({RoundSimulation simulation, Object map});

/// Builds one round's simulation for a schedule slot (architecture
/// doc § 3: physics construction lives in `app/game`, driven by map
/// data + the derived round seed). Overridable in tests.
typedef ShowSimulationFactory = ShowSimulationBundle Function(
  ShowSlot slot,
  int mapSeed,
  List<PlayerId> roster,
);

/// Builds the round's bot brains (host-side, GDD v2 § 9). Overridable
/// in tests so fake maps never reach the real bot factory.
typedef ShowBotBrainFactory = Map<PlayerId, BotBrain> Function(
  MiniGameId gameId, {
  required bool isFinal,
  required int mapSeed,
  required List<PlayerId> botIds,
  required Object map,
});

/// Default simulation factory: dispatches each schedule slot to its
/// built-in variant — Trap Race R1, Hammer Dodge R2, and the FINAL's
/// narrow Trap Race variant (`trap_race_final`) whose spawn slots
/// scale with the starter count (2-4, GDD v2 § 7.1 cascade).
ShowSimulationBundle defaultShowSimulationFactory(
  ShowSlot slot,
  int mapSeed,
  List<PlayerId> roster,
) => switch (slot.gameId) {
  'trap_race' => slot.isFinal
      ? _raceFinal(mapSeed, roster)
      : (
          simulation: RaceSimulation(
            map: CourseMap.trapRace(mapSeed),
            playerIds: roster,
          ),
          map: CourseMap.trapRace(mapSeed),
        ),
  'hammer_dodge' => _hammer(slot, mapSeed, roster),
  _ => throw ArgumentError.value(
    slot.gameId,
    'slot.gameId',
    'no simulation binding',
  ),
};

ShowSimulationBundle _raceFinal(int mapSeed, List<PlayerId> roster) {
  final map = CourseMap.trapRaceFinal(mapSeed, roster.length);
  return (
    simulation: RaceSimulation(
      map: map,
      playerIds: roster,
      variant: RaceVariant.finalRound,
    ),
    map: map,
  );
}

ShowSimulationBundle _hammer(
  ShowSlot slot,
  int mapSeed,
  List<PlayerId> roster,
) {
  final map = HammerArenaMap.hammerArena(mapSeed);
  return (
    simulation: HammerSimulation(
      map: map,
      playerIds: roster,
      quota: slot.quota,
    ),
    map: map,
  );
}

/// Default bot brains: one archetype brain per bot seat, seeded off
/// the round's map seed (GDD v2 § 9 — host-side, beatable but not
/// free).
Map<PlayerId, BotBrain> defaultShowBotBrainFactory(
  MiniGameId gameId, {
  required bool isFinal,
  required int mapSeed,
  required List<PlayerId> botIds,
  required Object map,
}) => {
  for (var i = 0; i < botIds.length; i++)
    botIds[i]: BotFactory.forGame(
      gameId,
      seed: mapSeed * botIds.length + i,
      map: map,
    ),
};
