import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/game_hud/ttr_score_strip.dart';
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

  testWidgets('shows the round chip when roundNumber is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrScoreStrip(entries: [], roundNumber: 2)),
      ),
    );

    expect(find.text('Round 2'), findsOneWidget);
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
