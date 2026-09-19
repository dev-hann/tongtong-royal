import 'package:app/design/game_hud/ttr_timer_badge.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the injected time label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '42')),
      ),
    );

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('numerals use the Fredoka SemiBold display face', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '42')),
      ),
    );

    final style = tester.widget<Text>(find.text('42')).style!;
    expect(style.fontFamily, FontTokens.display);
    expect(style.fontWeight!.value, TypeScale.numeralWeight);
  });

  testWidgets('follows injected time changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '60')),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '59')),
      ),
    );

    expect(find.text('59'), findsOneWidget);
    expect(find.text('60'), findsNothing);
  });

  testWidgets('pops on label change (guide § 4)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '60')),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrTimerBadge(timeLabel: '59')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    final scale = tester
        .widgetList<ScaleTransition>(find.byType(ScaleTransition))
        .first;
    expect(scale.scale.value, greaterThan(1));
    expect(scale.scale.value, lessThanOrEqualTo(MotionScales.pop));

    await tester.pump(MotionDurations.countdownPop);
    expect(
      tester
          .widgetList<ScaleTransition>(find.byType(ScaleTransition))
          .first
          .scale
          .value,
      1,
    );
  });
}
