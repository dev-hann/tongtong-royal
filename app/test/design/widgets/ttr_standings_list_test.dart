import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('rows and delta chips enter staggered (guide § 4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TtrStandingsList(
          entries: [
            StandingEntry(playerId: 'p1', totalPoints: 7, roundDelta: 4),
            StandingEntry(playerId: 'p2', totalPoints: 3, roundDelta: 3),
          ],
        ),
      ),
    );

    final staggers = tester.widgetList<TtrStaggeredEntrance>(
      find.byType(TtrStaggeredEntrance),
    );
    expect(staggers, hasLength(2));
    expect(staggers.map((s) => s.index), [0, 1]);
  });

  testWidgets('renders cumulative points with per-round delta chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TtrStandingsList(
          entries: [
            StandingEntry(playerId: 'p1', totalPoints: 7, roundDelta: 4),
            StandingEntry(playerId: 'p2', totalPoints: 3, roundDelta: 3),
            StandingEntry(playerId: 'p3', totalPoints: 0, roundDelta: 0),
          ],
        ),
      ),
    );

    expect(find.text('p1'), findsOneWidget);
    expect(find.text('p2'), findsOneWidget);
    expect(find.text('p3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('±0'), findsOneWidget);
  });

  testWidgets('displays entries verbatim in the given order', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrStandingsList(
          entries: [
            StandingEntry(playerId: 'b', totalPoints: 5, roundDelta: 1),
            StandingEntry(playerId: 'a', totalPoints: 9, roundDelta: 4),
          ],
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(texts.indexOf('b'), lessThan(texts.indexOf('a')));
  });
}
