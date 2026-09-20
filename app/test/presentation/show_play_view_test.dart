import 'package:app/design/widgets/ttr_quit_dialog.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/round_simulation.dart';
import 'package:app/presentation/show_play_view.dart';
import 'package:app/show/show_round_driver.dart';
import 'package:app/show/show_round_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  const roster = ['solo-player', 'bot-1', 'bot-2', 'bot-3'];
  const humanId = 'solo-player';

  ShowRoundSession buildSession(MiniGameId minigameId, int mapSeed,
      {bool isFinal = false}) {
    final game = const MinigameRegistry([TrapRace(), HammerDodge()])
        .byId(minigameId == 'trap_race_final' ? 'trap_race' : minigameId);
    final Object map;
    final RoundSimulation simulation;
    if (minigameId == 'hammer_dodge') {
      map = HammerArenaMap.hammerArena(mapSeed);
      simulation = HammerSimulation(
        map: map as HammerArenaMap,
        playerIds: roster,
        quota: 2,
      );
    } else if (isFinal) {
      map = CourseMap.trapRaceFinal(mapSeed, roster.length);
      simulation = RaceSimulation(
        map: map as CourseMap,
        playerIds: roster,
        variant: RaceVariant.finalRound,
      );
    } else {
      map = CourseMap.trapRace(mapSeed);
      simulation = RaceSimulation(map: map as CourseMap, playerIds: roster);
    }
    final driver = ShowRoundDriver(
      simulation: simulation,
      game: game,
      roundIndexZeroBased: 0,
      quota: isFinal ? 1 : 3,
      isFinal: isFinal,
      roster: roster.toSet(),
      humanId: humanId,
      brains: {
        for (var i = 1; i < roster.length; i++)
          roster[i]: BotFactory.forGame(
            minigameId == 'trap_race_final' ? 'trap_race' : minigameId,
            seed: mapSeed * roster.length + i,
            map: map,
          ),
      },
      map: map,
      onRoundComplete: (_) {},
    );
    return ShowRoundSession(
      driver: driver,
      simulation: simulation,
      map: map,
      minigameId: minigameId == 'trap_race_final' ? 'trap_race' : minigameId,
      isFinal: isFinal,
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
      MaterialApp(home: Scaffold(body: ShowPlayView(session: session))),
    );
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(session.simulation, isA<RaceSimulation>());
    expect((session.simulation as RaceSimulation).currentTick, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hammer session renders the arena view and stays healthy', (
    tester,
  ) async {
    final session = buildSession(BotFactory.hammerDodgeId, 7);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ShowPlayView(session: session))),
    );
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(session.simulation, isA<HammerSimulation>());
    expect((session.simulation as HammerSimulation).currentTick,
        greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('one button labeled JUMP fires the input edge', (tester) async {
    final session = buildSession(BotFactory.trapRaceId, 1);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ShowPlayView(session: session))),
    );
    await tester.pump();

    expect(find.text('JUMP'), findsOneWidget);

    await tester.tap(find.byKey(ShowPlayView.actionButtonKey));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('quit button opens the confirm dialog; QUIT fires onQuit', (
    tester,
  ) async {
    var quits = 0;
    final session = buildSession(BotFactory.hammerDodgeId, 3);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShowPlayView(session: session, onQuit: () => quits++),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(ShowPlayView.quitButtonKey));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(TtrQuitDialog.dialogKey), findsOneWidget);

    await tester.tap(find.byKey(TtrQuitDialog.confirmButtonKey));
    await tester.pump(const Duration(milliseconds: 300));

    expect(quits, 1);
  });

  testWidgets('system back opens the same quit confirm', (tester) async {
    final session = buildSession(BotFactory.trapRaceId, 2);
    addTearDown(session.driver.dispose);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ShowPlayView(session: session))),
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(TtrQuitDialog.dialogKey), findsOneWidget);
  });
}
