import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/game_playground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  testWidgets('pumps, renders frames and reports finish events', (
    tester,
  ) async {
    final map = CourseMap.trapRace(7);
    final sim = RaceSimulation(map: map, playerIds: ['p1']);
    addTearDown(sim.dispose);

    final received = <PlayerFinished>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GamePlayground(
            simulation: sim,
            localPlayerId: 'p1',
            map: map,
            onFinishEvent: received.add,
          ),
        ),
      ),
    );
    await tester.pump();

    // Put the player inside the finish sensor and let the frame loop
    // step the simulation until the event surfaces.
    sim.bodyOf('p1').setTransform(map.finishLine.center.clone(), 0);
    for (var i = 0; i < 8 && received.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(received, isNotEmpty);
    expect(received.single.playerId, 'p1');
    expect(tester.takeException(), isNull);
  });
}
