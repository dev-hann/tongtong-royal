import 'package:app/design/widgets/ttr_quit_dialog.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:app/solo/solo_play_view.dart';
import 'package:app/solo/solo_round_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  const roster = ['solo-player', 'bot-1', 'bot-2', 'bot-3'];
  const humanId = 'solo-player';

  SoloRoundSession buildSession(MiniGameId minigameId, int mapSeed) {
    final game = const MinigameRegistry().byId(minigameId);
    final map = switch (minigameId) {
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
    expect(session.simulation, isA<RaceSimulation>());
    expect((session.simulation as RaceSimulation).currentTick, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

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
    expect(session.simulation.poseOf(humanId)!.x, greaterThan(startX));
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.byKey(SoloPlayView.actionButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action button respects the bottom view padding', (tester) async {
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
          child: Scaffold(body: SoloPlayView(session: session)),
        ),
      ),
    );
    await tester.pump();

    final button = tester.getBottomRight(
      find.byKey(SoloPlayView.actionButtonKey),
    );
    // 32 visual margin + 24 inset = 56 px above the screen bottom.
    expect(button.dy, lessThan(600));
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

  testWidgets('quit button opens the confirm dialog; KEEP RUNNING stays', (
    tester,
  ) async {
    var quits = 0;
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoloPlayView(session: session, onQuit: () => quits++),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(SoloPlayView.quitButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(TtrQuitDialog.dialogKey), findsOneWidget);
    expect(find.text('Quit the race?'), findsOneWidget);
    expect(quits, 0, reason: 'dialog alone must not quit');

    await tester.tap(find.byKey(TtrQuitDialog.keepRunningButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(TtrQuitDialog.dialogKey), findsNothing);
    expect(quits, 0);
  });

  testWidgets('confirming QUIT in the dialog fires onQuit once', (
    tester,
  ) async {
    var quits = 0;
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoloPlayView(session: session, onQuit: () => quits++),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(SoloPlayView.quitButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(TtrQuitDialog.confirmButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(quits, 1);
    expect(find.byKey(TtrQuitDialog.dialogKey), findsNothing);
  });

  testWidgets('system back during play shows the quit dialog, not exit', (
    tester,
  ) async {
    var quits = 0;
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoloPlayView(session: session, onQuit: () => quits++),
        ),
      ),
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Back is intercepted: the dialog appears, nothing pops or quits.
    expect(find.byKey(TtrQuitDialog.dialogKey), findsOneWidget);
    expect(quits, 0);
    expect(find.byKey(SoloPlayView.actionButtonKey), findsOneWidget);
  });
}
