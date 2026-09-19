import 'package:app/presentation/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('HUD shows injected scores, round chip and timer verbatim', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [
            ScoreEntry(playerId: 'a', points: 7),
            ScoreEntry(playerId: 'b', points: 4),
          ],
          timeRemaining: '42',
          roundNumber: 2,
          totalRounds: 3,
        ),
      ),
    );

    expect(find.byKey(GameScreen.gameViewportKey), findsOneWidget);
    expect(find.text('a: 7'), findsOneWidget);
    expect(find.text('b: 4'), findsOneWidget);
    expect(find.text('Round 2 / 3'), findsOneWidget);
    expect(find.byKey(GameScreen.timerKey), findsOneWidget);
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

  testWidgets('remainingSeconds seeds the live timer badge', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 90,
        ),
      ),
    );
    expect(find.text('90'), findsOneWidget);
  });

  testWidgets('live timer counts down locally between rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 5,
        ),
      ),
    );
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('live timer clamps at zero', (tester) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('live timer re-seeds when the injected value changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 10,
        ),
      ),
    );
    await tester.pumpWidget(
      wrap(
        const GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 60,
        ),
      ),
    );
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('HUD is protected by SafeArea (design guide 8)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          scoreboard: [],
          timeRemaining: '',
          remainingSeconds: 60,
        ),
      ),
    );
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
