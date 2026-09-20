import 'package:app/presentation/show_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows round pill, banner, verb and countdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ShowIntroScreen(
          roundNumber: 2,
          totalRounds: 3,
          gameName: 'Hammer Dodge',
          ruleLine: 'Last two standing qualify',
          verb: 'JUMP',
          countdownValue: 3,
        ),
      ),
    );

    expect(find.text('ROUND 2 / 3'), findsOneWidget);
    expect(find.text('Hammer Dodge'), findsOneWidget);
    expect(find.text('Last two standing qualify'), findsOneWidget);
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('system back during the intro requests the quit confirm', (
    tester,
  ) async {
    var quitRequested = 0;
    await tester.pumpWidget(
      wrap(
        ShowIntroScreen(
          roundNumber: 1,
          totalRounds: 3,
          gameName: 'Trap Race',
          ruleLine: 'First to the finish line',
          verb: 'JUMP',
          countdownValue: 2,
          onQuitAttempt: () => quitRequested++,
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(quitRequested, 1, reason: 'GDD v2 § 7.4: back confirms, never pops');
  });

  testWidgets('final intro keeps the same layout with the final pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ShowIntroScreen(
          roundNumber: 3,
          totalRounds: 3,
          gameName: 'Trap Race Final',
          ruleLine: 'First finisher takes the crown',
          verb: 'JUMP',
          countdownValue: 1,
          isFinal: true,
        ),
      ),
    );

    expect(find.text('ROUND 3 / 3'), findsOneWidget);
    expect(find.text('Trap Race Final'), findsOneWidget);
    expect(find.text('First finisher takes the crown'), findsOneWidget);
  });
}
