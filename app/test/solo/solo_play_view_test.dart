import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/arenas/hill/hill_simulation.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:app/solo/solo_play_view.dart';
import 'package:app/solo/solo_round_driver.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  const roster = ['solo-player', 'bot-1', 'bot-2', 'bot-3'];
  const humanId = 'solo-player';

  SoloRoundSession buildSession(MiniGameId minigameId, int mapSeed) {
    final game = const MinigameRegistry().byId(minigameId);
    final map = switch (minigameId) {
      BotFactory.hammerDodgeId => HammerArenaMap.hammerArena(mapSeed),
      BotFactory.kingOfTheHillId => HillArenaMap.kingOfTheHill(mapSeed),
      _ => CourseMap.trapRace(mapSeed),
    };
    final simulation = defaultRoundSimulationFactory(
      minigameId,
      mapSeed,
      roster,
    );
    final driver = SoloRoundDriver(
      simulation: simulation,
      game: game,
      roundIndex: 0,
      roster: roster.toSet(),
      humanId: humanId,
      brains: {
        for (var i = 1; i < roster.length; i++)
          roster[i]: BotFactory.forGame(
            minigameId,
            seed: mapSeed * roster.length + i,
            map: map,
          ),
      },
      map: map,
      onRoundComplete: (_) {},
    );
    return SoloRoundSession(
      driver: driver,
      simulation: simulation,
      map: map,
      minigameId: minigameId,
      humanId: humanId,
      rosterIds: roster,
    );
  }

  int tickCountOf(Object simulation) => switch (simulation) {
    final RaceSimulation race => race.currentTick,
    final HammerSimulation hammer => hammer.currentTick,
    final HillSimulation hill => hill.currentTick,
    _ => throw ArgumentError('unknown simulation'),
  };

  testWidgets('race session pumps frames, ticks bots, stays healthy', (
    tester,
  ) async {
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SoloPlayView(session: session)),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The Flame loop stepped the simulation (human + bot inputs fed).
    expect(tickCountOf(session.simulation), greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'hammer': BotFactory.hammerDodgeId,
    'hill': BotFactory.kingOfTheHillId,
  }.entries) {
    testWidgets('arena session (${entry.key}) mounts ArenaGameView', (
      tester,
    ) async {
      final session = buildSession(entry.value, 3);
      addTearDown(session.driver.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SoloPlayView(session: session)),
        ),
      );
      await tester.pump();

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Arena rounds render through the real Flame loop too.
      expect(find.byType(GameWidget), findsOneWidget);
      expect(session.driver.tickCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }
}
