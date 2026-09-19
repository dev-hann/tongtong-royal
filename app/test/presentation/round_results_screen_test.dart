import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const result = RoundResult(
    roundIndex: 1,
    minigameId: 'hammer_dodge',
    placements: [
      Placement(playerId: 'p1', rank: 1, points: 4),
      Placement(playerId: 'p2', rank: 2, points: 3),
      Placement(playerId: 'p3', rank: 3, points: 2),
    ],
  );

  RoundResultsScreen build({int? autoAdvanceSeconds}) => RoundResultsScreen(
    result: result,
    roundNumber: 2,
    totalRounds: 3,
    minigameName: 'Hammer Dodge',
    standings: const [
      StandingEntry(playerId: 'p1', totalPoints: 7, roundDelta: 4),
      StandingEntry(playerId: 'p2', totalPoints: 3, roundDelta: 3),
      StandingEntry(playerId: 'p3', totalPoints: 2, roundDelta: 2),
    ],
    autoAdvanceSeconds: autoAdvanceSeconds,
  );

  testWidgets('shows header pill with round, total and minigame name', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));

    expect(
      find.byKey(RoundResultsScreen.headerKey),
      findsOneWidget,
    );
    expect(find.text('ROUND 2 / 3 · HAMMER DODGE'), findsOneWidget);
  });

  testWidgets('shows round placements and cumulative standings with deltas', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));

    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('auto-advance progress bar fills over the dwell window', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build(autoAdvanceSeconds: 6)));
    await tester.pump(const Duration(milliseconds: 100));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(RoundResultsScreen.autoAdvanceKey),
    );
    final early = bar.value ?? 0;
    expect(early, lessThan(0.3));

    await tester.pump(const Duration(seconds: 3));
    final mid = tester.widget<LinearProgressIndicator>(
      find.byKey(RoundResultsScreen.autoAdvanceKey),
    ).value!;
    expect(mid, greaterThan(early));
    expect(mid, lessThan(1));

    await tester.pump(const Duration(seconds: 3));
    final done = tester.widget<LinearProgressIndicator>(
      find.byKey(RoundResultsScreen.autoAdvanceKey),
    ).value;
    expect(done, isNull); // completed controller reports null value
  });

  testWidgets('no progress bar when autoAdvanceSeconds is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));
    expect(find.byKey(RoundResultsScreen.autoAdvanceKey), findsNothing);
  });

  testWidgets('renders placement rows verbatim in domain order', (
    tester,
  ) async {
    const unsorted = RoundResult(
      roundIndex: 2,
      minigameId: 'hammer_dodge',
      placements: [
        Placement(playerId: 'p2', rank: 2, points: 3),
        Placement(playerId: 'p1', rank: 1, points: 4),
      ],
    );
    await tester.pumpWidget(
      wrap(const RoundResultsScreen(result: unsorted)),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((text) => text.startsWith('p'))
        .toList();
    expect(texts, ['p2', 'p1']);
  });

  testWidgets('waiting placeholder when result is null', (tester) async {
    await tester.pumpWidget(
      wrap(const RoundResultsScreen(roundNumber: 1, totalRounds: 3)),
    );
    expect(find.text('Waiting for results...'), findsOneWidget);
  });
}
