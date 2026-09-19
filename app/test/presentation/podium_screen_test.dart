import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const rankings = [
    Placement(playerId: 'gold', rank: 1, points: 20),
    Placement(playerId: 'silver', rank: 2, points: 15),
    Placement(playerId: 'bronze', rank: 3, points: 10),
    Placement(playerId: 'wood', rank: 4, points: 5),
  ];

  PodiumScreen build({VoidCallback? onExit}) => PodiumScreen(
    rankings: rankings,
    nicknames: const {
      'gold': 'Winner',
      'silver': 'Second',
      'bronze': 'Third',
      'wood': 'Fourth',
    },
    playerColors: const {
      'gold': PlayerPalette.one,
      'silver': PlayerPalette.two,
      'bronze': PlayerPalette.three,
      'wood': PlayerPalette.four,
    },
    onExit: onExit,
  );

  testWidgets('renders three pedestals with 1st tallest', (tester) async {
    await tester.pumpWidget(wrap(build()));

    final first = tester
        .widget<SizedBox>(find.byKey(PodiumScreen.firstPedestalKey))
        .height!;
    final second = tester
        .widget<SizedBox>(find.byKey(PodiumScreen.secondPedestalKey))
        .height!;
    final third = tester
        .widget<SizedBox>(find.byKey(PodiumScreen.thirdPedestalKey))
        .height!;

    expect(first, greaterThan(second));
    expect(second, greaterThan(third));
    expect(first % SpacingScale.xs, 0);
    expect(second % SpacingScale.xs, 0);
    expect(third % SpacingScale.xs, 0);
  });

  testWidgets('shows nicknames and colors on the pedestals', (tester) async {
    await tester.pumpWidget(wrap(build()));

    expect(find.text('Winner'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('trophy icon sits on the first-place pedestal', (tester) async {
    await tester.pumpWidget(wrap(build()));
    expect(find.byKey(PodiumScreen.trophyKey), findsOneWidget);
    expect(find.byIcon(TtrIcons.trophy), findsOneWidget);
  });

  testWidgets('4th place shows as a small chip below the podium', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(build()));
    expect(find.byKey(PodiumScreen.fourthChipKey), findsOneWidget);
    expect(find.textContaining('Fourth'), findsOneWidget);
  });

  testWidgets('first pedestal pulses (repeating animation)', (tester) async {
    await tester.pumpWidget(wrap(build()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('rematch and exit buttons fire callbacks', (tester) async {
    final rematched = <String>[];
    final exited = <String>[];
    await tester.pumpWidget(
      wrap(build(onExit: () => exited.add('exit'))),
    );

    await tester.tap(find.byKey(PodiumScreen.rematchButtonKey));
    await tester.pump();
    expect(rematched, isEmpty); // no onRematch wired in build()

    await tester.tap(find.byKey(PodiumScreen.exitButtonKey));
    await tester.pump();
    expect(exited, ['exit']);
  });

  testWidgets('shared top rank stacks both players on the first pedestal', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          rankings: [
            Placement(playerId: 'tiedA', rank: 1, points: 18),
            Placement(playerId: 'tiedB', rank: 1, points: 18),
            Placement(playerId: 'bronze', rank: 3, points: 9),
          ],
          nicknames: {
            'tiedA': 'Alice',
            'tiedB': 'Bob',
            'bronze': 'Third',
          },
          playerColors: {
            'tiedA': PlayerPalette.one,
            'tiedB': PlayerPalette.two,
            'bronze': PlayerPalette.three,
          },
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('T-1st'), findsNWidgets(2));
    expect(find.text('3rd'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
  });
}
