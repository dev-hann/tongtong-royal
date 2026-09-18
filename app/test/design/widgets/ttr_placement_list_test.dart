import 'package:app/design/widgets/ttr_placement_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders rank, player and points per row', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrPlacementList(
          placements: [
            Placement(playerId: 'p1', rank: 1, points: 4),
            Placement(playerId: 'p2', rank: 2, points: 3),
          ],
        ),
      ),
    );

    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
    expect(find.text('p1'), findsOneWidget);
    expect(find.text('p2'), findsOneWidget);
    expect(find.text('4 pt'), findsOneWidget);
    expect(find.text('3 pt'), findsOneWidget);
  });

  testWidgets('shared ranks are labeled T-<ordinal>', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrPlacementList(
          placements: [
            Placement(playerId: 'tiedA', rank: 1, points: 18),
            Placement(playerId: 'tiedB', rank: 1, points: 18),
            Placement(playerId: 'bronze', rank: 3, points: 9),
          ],
        ),
      ),
    );

    expect(find.text('T-1st'), findsNWidgets(2));
    expect(find.text('1st'), findsNothing);
    expect(find.text('3rd'), findsOneWidget);
  });

  testWidgets('renders rows verbatim in passed-in order', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrPlacementList(
          placements: [
            Placement(playerId: 'p2', rank: 2, points: 3),
            Placement(playerId: 'p1', rank: 1, points: 4),
          ],
        ),
      ),
    );

    final displayedIds = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((text) => text.startsWith('p'))
        .toList();
    expect(displayedIds, ['p2', 'p1']);
  });

  testWidgets('4th and beyond render with th ordinal', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrPlacementList(
          placements: [Placement(playerId: 'p4', rank: 4, points: 1)],
        ),
      ),
    );

    expect(find.text('4th'), findsOneWidget);
  });
}
