import 'package:app/design/game_hud/ttr_timer_badge.dart';
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
}
