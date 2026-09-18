import 'package:app/design/widgets/ttr_round_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows minigame title and one-line rule', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TtrRoundBanner(
            title: 'Trap Race',
            ruleLine: 'First to the finish line wins.',
          ),
        ),
      ),
    );

    expect(find.text('Trap Race'), findsOneWidget);
    expect(find.text('First to the finish line wins.'), findsOneWidget);
  });
}
