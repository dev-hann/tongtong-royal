import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders soft token-colored shapes over the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TtrAmbientBackdrop())),
    );
    await tester.pump(const Duration(seconds: 1));

    final shapes = tester.widgetList<DecoratedBox>(
      find.byKey(TtrAmbientBackdrop.shapeKey),
    );
    expect(shapes.length, greaterThanOrEqualTo(3));

    final fills = shapes
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((deco) => deco.color)
        .toSet();
    final softTints = {
      ColorPalette.primarySoft,
      ColorPalette.secondarySoft,
      ColorPalette.warningSoft,
    };
    expect(fills.every(softTints.contains), isTrue);
  });

  testWidgets('animation keeps running without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TtrAmbientBackdrop())),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isTrue);
  });
}
