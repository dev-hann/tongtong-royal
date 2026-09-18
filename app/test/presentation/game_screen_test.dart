import 'package:app/presentation/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('HUD shows injected scores and timer verbatim', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [
            ScoreEntry(playerId: 'a', points: 7),
            ScoreEntry(playerId: 'b', points: 4),
          ],
          timeRemaining: '42',
        ),
      ),
    );

    expect(find.byKey(GameScreen.gameViewportKey), findsOneWidget);
    expect(find.text('a: 7'), findsOneWidget);
    expect(find.text('b: 4'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('timer text changes when injected value changes', (tester) async {
    await tester.pumpWidget(
      wrap(const GameScreen(scoreboard: [], timeRemaining: '60')),
    );
    expect(find.text('60'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const GameScreen(scoreboard: [], timeRemaining: '59')),
    );
    expect(find.text('59'), findsOneWidget);
  });
}
