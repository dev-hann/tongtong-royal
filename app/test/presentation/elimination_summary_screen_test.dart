import 'package:app/presentation/elimination_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows own verdict, champion line, deltas and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EliminationSummaryScreen(
          eliminatedInRound: 2,
          championLine: 'BOT 2 takes the crown',
          statDeltas: ['SHOWS +1'],
        ),
      ),
    );

    expect(find.text('ELIMINATED IN ROUND 2'), findsOneWidget);
    expect(find.text('BOT 2 takes the crown'), findsOneWidget);
    expect(find.text('SHOWS +1'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('tapping HOME fires the exit callback', (tester) async {
    var exits = 0;
    await tester.pumpWidget(
      wrap(
        EliminationSummaryScreen(
          eliminatedInRound: 1,
          championLine: 'BOT 1 takes the crown',
          onExitHome: () => exits++,
        ),
      ),
    );

    await tester.tap(find.text('HOME'));
    await tester.pump();

    expect(exits, 1);
  });

  testWidgets('system back exits to home, never pops the shell', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(
      wrap(
        EliminationSummaryScreen(
          eliminatedInRound: 1,
          championLine: 'BOT 1 takes the crown',
          onExitHome: () => exits++,
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(exits, 1);
  });
}
