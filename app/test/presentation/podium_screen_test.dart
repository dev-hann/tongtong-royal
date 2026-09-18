import 'package:app/presentation/podium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows 1st, 2nd, 3rd in order from rankings', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          rankings: [
            Placement(playerId: 'winner', rank: 1, points: 20),
            Placement(playerId: 'second', rank: 2, points: 15),
            Placement(playerId: 'third', rank: 3, points: 10),
            Placement(playerId: 'fourth', rank: 4, points: 5),
          ],
        ),
      ),
    );

    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('winner'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    // Top-3 podium only: 4th place is not shown.
    expect(find.text('fourth'), findsNothing);
    expect(find.text('4th'), findsNothing);
  });

  testWidgets('shared rank shows T-label and both tied names', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          rankings: [
            Placement(playerId: 'tiedA', rank: 1, points: 18),
            Placement(playerId: 'tiedB', rank: 1, points: 18),
            Placement(playerId: 'bronze', rank: 3, points: 9),
          ],
        ),
      ),
    );

    expect(find.text('tiedA'), findsOneWidget);
    expect(find.text('tiedB'), findsOneWidget);
    expect(find.text('T-1st'), findsNWidgets(2));
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('bronze'), findsOneWidget);
    // No plain 1st when the top rank is shared.
    expect(find.text('1st'), findsNothing);
  });

  testWidgets('rematch button fires callback', (tester) async {
    var rematched = false;
    await tester.pumpWidget(
      wrap(
        PodiumScreen(
          rankings: const [Placement(playerId: 'winner', rank: 1, points: 20)],
          onRematch: () => rematched = true,
        ),
      ),
    );

    await tester.tap(find.byKey(PodiumScreen.rematchButtonKey));
    await tester.pump();
    expect(rematched, isTrue);
  });
}
