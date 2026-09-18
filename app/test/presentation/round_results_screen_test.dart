import 'package:app/presentation/round_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('shows placements and points from the passed-in result', (
    tester,
  ) async {
    const result = RoundResult(
      roundIndex: 0,
      minigameId: 'trap_race',
      placements: [
        Placement(playerId: 'p1', rank: 1, points: 4),
        Placement(playerId: 'p2', rank: 2, points: 3),
        Placement(playerId: 'p3', rank: 3, points: 2),
      ],
    );

    await tester.pumpWidget(wrap(const RoundResultsScreen(result: result)));

    expect(find.text('p1'), findsOneWidget);
    expect(find.text('p2'), findsOneWidget);
    expect(find.text('p3'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('4 pt'), findsOneWidget);
    expect(find.text('3 pt'), findsOneWidget);
    expect(find.text('2 pt'), findsOneWidget);
  });

  testWidgets('renders rows verbatim in passed-in order (no recompute)', (
    tester,
  ) async {
    // Pre-computed domain values, deliberately not sorted by the widget:
    // the screen must display them exactly as delivered.
    const result = RoundResult(
      roundIndex: 2,
      minigameId: 'hammer_dodge',
      placements: [
        Placement(playerId: 'p2', rank: 2, points: 3),
        Placement(playerId: 'p1', rank: 1, points: 4),
        Placement(playerId: 'p3', rank: 3, points: 1),
      ],
    );

    await tester.pumpWidget(wrap(const RoundResultsScreen(result: result)));

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(rows, hasLength(3));

    final displayedIds = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((text) => text.startsWith('p'))
        .toList();
    expect(displayedIds, ['p2', 'p1', 'p3']);
  });
}
