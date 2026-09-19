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

    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.text('WINS'), findsOneWidget);
    expect(find.text('1ST PLACES'), findsOneWidget);
    expect(find.text('BEST TIME'), findsOneWidget);
  });
}
