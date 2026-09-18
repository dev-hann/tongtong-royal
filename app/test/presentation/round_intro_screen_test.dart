import 'package:app/presentation/round_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('shows minigame name, rule line, injected countdown value', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const RoundIntroScreen(
          minigameName: 'Trap Race',
          ruleLine: 'First to the finish line wins.',
          countdownValue: 2,
        ),
      ),
    );

    expect(find.text('Trap Race'), findsOneWidget);
    expect(find.text('First to the finish line wins.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('countdown display follows the injected ticker value', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const RoundIntroScreen(
          minigameName: 'Trap Race',
          ruleLine: 'rule',
          countdownValue: 3,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const RoundIntroScreen(
          minigameName: 'Trap Race',
          ruleLine: 'rule',
          countdownValue: 1,
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}
