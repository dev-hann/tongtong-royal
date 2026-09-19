import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/game_hud/ttr_score_strip.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders cumulative points per player', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrScoreStrip(
            entries: [
              ScoreEntry(playerId: 'a', points: 7),
              ScoreEntry(playerId: 'b', points: 4),
            ],
          ),
        ),
      ),
    );

    expect(find.text('a: 7'), findsOneWidget);
    expect(find.text('b: 4'), findsOneWidget);
  });

  testWidgets('numerals use the Fredoka SemiBold display face', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrScoreStrip(entries: [ScoreEntry(playerId: 'a', points: 7)]),
        ),
      ),
    );

    final style = tester.widget<Text>(find.text('a: 7')).style!;
    expect(style.fontFamily, FontTokens.display);
    expect(style.fontWeight!.value, TypeScale.numeralWeight);
  });

  testWidgets('score pops on change (guide § 4)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrScoreStrip(entries: [ScoreEntry(playerId: 'a', points: 7)]),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrScoreStrip(entries: [ScoreEntry(playerId: 'a', points: 8)]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('a: 8'), findsOneWidget);
    final scale = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .first;
    expect(scale.scale.value, greaterThan(1));
    expect(scale.scale.value, lessThanOrEqualTo(MotionScales.pop));

    await tester.pump(MotionDurations.countdownPop);
    expect(
      tester
          .widgetList<ScaleTransition>(find.byType(ScaleTransition))
          .first
          .scale
          .value,
      1,
    );
  });

  testWidgets('shows the round chip when roundNumber is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrScoreStrip(entries: [], roundNumber: 2)),
      ),
    );

    expect(find.text('Round 2'), findsOneWidget);
  });

  testWidgets('round chip shows total when totalRounds is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrScoreStrip(entries: [], roundNumber: 2, totalRounds: 3),
        ),
      ),
    );

    expect(find.text('Round 2 / 3'), findsOneWidget);
    expect(find.text('Round 2'), findsNothing);
  });

  testWidgets('hides the round chip when roundNumber is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrScoreStrip(entries: [])),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });
}
