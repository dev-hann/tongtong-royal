import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
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

  for (final entry in {'hammer': BotFactory.hammerDodgeId}.entries) {
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

  testWidgets('race: one button labeled JUMP auto-runs the human', (
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

    final startX = session.simulation.poseOf(humanId)!.x;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Auto-steering feeds the sim: constant rightward movement.
    expect(
      session.simulation.poseOf(humanId)!.x,
      greaterThan(startX),
    );
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.byKey(SoloPlayView.actionButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('race: tapping the button jumps the human', (tester) async {
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SoloPlayView(session: session)),
      ),
    );
    await tester.pump();

    // Let the loop run at least one step so the grounded flag is
    // live before the tap (first-ever tick precedes any contact
    // solve).
    await tester.pump(const Duration(milliseconds: 100));

    final startY = session.simulation.poseOf(humanId)!.y;
    var maxY = startY;
    await tester.tap(find.byKey(SoloPlayView.actionButtonKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final y = session.simulation.poseOf(humanId)?.y;
      if (y != null && y > maxY) {
        maxY = y;
      }
    }

    // The press edge reached the simulation as a grounded jump.
    expect(maxY, greaterThan(startY + 0.1));
    expect(tester.takeException(), isNull);
  });
}
