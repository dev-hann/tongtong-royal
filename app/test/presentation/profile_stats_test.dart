import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows a dash for the best time when no record exists', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ProfileStatsRow(stats: Stats())));

    expect(find.text('BEST TIME'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('shows the persisted best time in seconds', (tester) async {
    await tester.pumpWidget(
      wrap(const ProfileStatsRow(stats: Stats(), bestTimeMs: 45670)),
    );

    expect(find.text('BEST TIME'), findsOneWidget);
    expect(find.text('45.67s'), findsOneWidget);
  });

  testWidgets('renders the four record cards in a row', (tester) async {
    await tester.pumpWidget(wrap(const ProfileStatsRow(stats: Stats())));

    expect(find.text('CROWNS'), findsOneWidget);
    expect(find.text('FINALS'), findsOneWidget);
    expect(find.text('SHOWS'), findsOneWidget);
    expect(find.text('BEST TIME'), findsOneWidget);
  });

  testWidgets('renders the crown stats values (GDD v2 § 2)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProfileStatsRow(
          stats: Stats(showsPlayed: 3, finalsReached: 1, crownsWon: 1),
        ),
      ),
    );

    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
  });
}
