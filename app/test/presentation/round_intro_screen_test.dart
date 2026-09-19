import 'package:app/presentation/round_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  RoundIntroScreen build({int? roundNumber, int? totalRounds}) =>
      RoundIntroScreen(
        minigameName: 'Trap Race',
        ruleLine: 'First to the finish line wins.',
        countdownValue: 2,
        roundNumber: roundNumber,
        totalRounds: totalRounds,
      );

  testWidgets('shows minigame name, rule line, injected countdown value', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));

    expect(find.text('Trap Race'), findsOneWidget);
    expect(find.text('First to the finish line wins.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows the ROUND n / total badge pill', (tester) async {
    await tester.pumpWidget(
      wrap(build(roundNumber: 2, totalRounds: 3)),
    );

    expect(find.text('ROUND 2 / 3'), findsOneWidget);
    expect(find.byKey(RoundIntroScreen.roundBadgeKey), findsOneWidget);
  });

  testWidgets('badge hidden when round number is not provided', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));
    expect(find.byKey(RoundIntroScreen.roundBadgeKey), findsNothing);
  });

  testWidgets('countdown display follows the injected ticker value', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build(roundNumber: 1, totalRounds: 3)));
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const RoundIntroScreen(
          minigameName: 'Trap Race',
          ruleLine: 'rule',
          countdownValue: 1,
          roundNumber: 1,
          totalRounds: 3,
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
