import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows the injected value as text', (tester) async {
    await tester.pumpWidget(wrap(const TtrCountdown(value: 3)));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('follows value changes', (tester) async {
    await tester.pumpWidget(wrap(const TtrCountdown(value: 3)));
    await tester.pumpWidget(wrap(const TtrCountdown(value: 2)));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('numerals use the Fredoka SemiBold display role', (tester) async {
    await tester.pumpWidget(wrap(const TtrCountdown(value: 3)));

    final style = tester.widget<Text>(find.text('3')).style!;
    expect(style.fontFamily, FontTokens.display);
    expect(style.fontWeight!.value, TypeScale.numeralWeight);
  });

  testWidgets('pops past 1.0 on every value change (guide § 4)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const TtrCountdown(value: 3)));
    await tester.pumpAndSettle();

    await tester.pumpWidget(wrap(const TtrCountdown(value: 2)));
    await tester.pump(const Duration(milliseconds: 60));

    final scale = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .first;
    expect(scale.scale.value, greaterThan(1));
    expect(scale.scale.value, lessThanOrEqualTo(MotionScales.pop));
  });

  testWidgets('pop animation settles at scale 1', (tester) async {
    await tester.pumpWidget(wrap(const TtrCountdown(value: 3)));
    await tester.pumpAndSettle();

    final scale = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .first;
    expect(scale.scale.value, 1);
  });
}
