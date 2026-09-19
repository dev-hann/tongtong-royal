import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const result = RoundResult(
    roundIndex: 0,
    minigameId: 'trap_race',
    placements: [
      Placement(playerId: 'p1', rank: 1, points: 4),
      Placement(playerId: 'p2', rank: 2, points: 3),
      Placement(playerId: 'p3', rank: 3, points: 2),
    ],
  );

  RoundResultsScreen build({
    VoidCallback? onPlayAgain,
    VoidCallback? onExitHome,
  }) => RoundResultsScreen(
    result: result,
    roundNumber: 1,
    totalRounds: 1,
    minigameName: 'Trap Race',
    standings: const [
      StandingEntry(playerId: 'p1', totalPoints: 4, roundDelta: 4),
      StandingEntry(playerId: 'p2', totalPoints: 3, roundDelta: 3),
      StandingEntry(playerId: 'p3', totalPoints: 2, roundDelta: 2),
    ],
    onPlayAgain: onPlayAgain,
    onExitHome: onExitHome,
  );

  testWidgets('shows header pill with round, total and minigame name', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));

    expect(find.byKey(RoundResultsScreen.headerKey), findsOneWidget);
    expect(find.text('ROUND 1 / 1 · TRAP RACE'), findsOneWidget);
  });

  testWidgets('shows round placements and standings with deltas', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));

    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget);
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('terminal screen: PLAY AGAIN and HOME buttons fire', (
    tester,
  ) async {
    var playAgain = 0;
    var exitHome = 0;
    await tester.pumpWidget(
      wrap(build(onPlayAgain: () => playAgain++, onExitHome: () => exitHome++)),
    );

    await tester.tap(find.byKey(RoundResultsScreen.playAgainButtonKey));
    await tester.pump();
    expect(playAgain, 1);

    await tester.tap(find.byKey(RoundResultsScreen.exitHomeButtonKey));
    await tester.pump();
    expect(exitHome, 1);
  });

  testWidgets('no auto-advance progress bar (terminal screen)', (tester) async {
    await tester.pumpWidget(wrap(build()));
    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('renders placement rows verbatim in domain order', (
    tester,
  ) async {
    const unsorted = RoundResult(
      roundIndex: 0,
      minigameId: 'trap_race',
      placements: [
        Placement(playerId: 'p2', rank: 2, points: 3),
        Placement(playerId: 'p1', rank: 1, points: 4),
      ],
    );
    await tester.pumpWidget(wrap(const RoundResultsScreen(result: unsorted)));

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
      wrap(const RoundResultsScreen(roundNumber: 1, totalRounds: 1)),
    );
    expect(find.text('Waiting for results...'), findsOneWidget);
  });
}
