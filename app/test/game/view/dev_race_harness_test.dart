import 'package:app/game/view/dev_race_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pumps and restarts without exceptions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DevRaceHarness(mapSeed: 42))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(DevRaceHarness.restartButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DevRaceHarness), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
