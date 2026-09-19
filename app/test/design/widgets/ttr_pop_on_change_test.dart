import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_pop_on_change.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Object tag) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: TtrPopOnChange(tag: tag, child: const Text('42')),
      ),
    ),
  );

  testWidgets('does not pop on first build', (tester) async {
    await tester.pumpWidget(wrap(7));

    final scale = tester.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(TtrPopOnChange),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('pops 1.0 → peak → 1.0 when the tag changes', (tester) async {
    await tester.pumpWidget(wrap(7));
    await tester.pumpWidget(wrap(8));
    await tester.pump(const Duration(milliseconds: 60));

    var scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(TtrPopOnChange),
          matching: find.byType(ScaleTransition),
        ),
      );
    final mid = scale.scale.value;
    expect(mid, greaterThan(1));
    expect(mid, lessThanOrEqualTo(MotionScales.pop));

    await tester.pump(MotionDurations.countdownPop);
    scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(TtrPopOnChange),
          matching: find.byType(ScaleTransition),
        ),
      );
    expect(scale.scale.value, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('pop never exceeds the peak token', (tester) async {
    await tester.pumpWidget(wrap(7));
    await tester.pumpWidget(wrap(8));
    for (var t = 0; t <= 150; t += 15) {
      await tester.pump(const Duration(milliseconds: 15));
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(TtrPopOnChange),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, lessThanOrEqualTo(MotionScales.pop));
    }
  });

  testWidgets('initialPop fires on mount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TtrPopOnChange(
              tag: 3,
              initialPop: true,
              child: Text('3'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(TtrPopOnChange),
          matching: find.byType(ScaleTransition),
        ),
      );
    expect(scale.scale.value, greaterThan(1));
  });
}
