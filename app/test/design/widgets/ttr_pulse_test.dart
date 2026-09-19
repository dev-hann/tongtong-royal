import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap() => const MaterialApp(
    home: Scaffold(
      body: Center(child: TtrPulse(child: Text('1st'))),
    ),
  );

  testWidgets('runs a repeating pulse between 1.0 and the peak token', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(MotionDurations.pulse * 0.5);
    final rising = tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(TtrPulse),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    expect(rising, greaterThan(1));
    expect(rising, lessThanOrEqualTo(MotionScales.pulse));

    await tester.pump(MotionDurations.pulse);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('scale stays inside the 1.0–1.04 band across the loop', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    for (var t = 0; t < 1800; t += 90) {
      await tester.pump(const Duration(milliseconds: 90));
      final value = tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(TtrPulse),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      expect(value, greaterThanOrEqualTo(1));
      expect(value, lessThanOrEqualTo(MotionScales.pulse));
    }
  });
}
