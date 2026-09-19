import 'package:app/presentation/credits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists both bundled fonts with license', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreditsScreen())),
    );

    expect(find.text('Fredoka font'), findsOneWidget);
    expect(find.text('Nunito font'), findsOneWidget);
    expect(find.textContaining('SIL OFL 1.1'), findsNWidgets(2));
    expect(find.byKey(CreditsScreen.fredokaRowKey), findsOneWidget);
    expect(find.byKey(CreditsScreen.nunitoRowKey), findsOneWidget);
  });
}
