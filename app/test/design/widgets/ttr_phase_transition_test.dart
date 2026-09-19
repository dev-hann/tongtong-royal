import 'package:app/design/widgets/ttr_phase_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: TtrPhaseTransition(child: child)));

  testWidgets('shows the current child', (tester) async {
    await tester.pumpWidget(host(const Text('first')));
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('swaps children with fade+slide transition', (tester) async {
    await tester.pumpWidget(host(const KeyedSubtree(
      key: ValueKey('a'),
      child: Text('first'),
    )));
    await tester.pumpWidget(host(const KeyedSubtree(
      key: ValueKey('b'),
      child: Text('second'),
    )));

    // Mid-transition both children exist (AnimatedSwitcher cross-fade).
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);

    // After the full transition duration the old child is gone.
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('entering screen slides UP from below (guide § 4)', (
    tester,
  ) async {
    await tester.pumpWidget(host(const KeyedSubtree(
      key: ValueKey('a'),
      child: Text('first'),
    )));
    await tester.pumpWidget(host(const KeyedSubtree(
      key: ValueKey('b'),
      child: Text('second'),
    )));

    // Mid-transition the incoming child's slide offset starts below
    // its resting slot (positive dy) and travels toward zero.
    await tester.pump(const Duration(milliseconds: 40));
    final incoming = tester
        .widgetList<SlideTransition>(
          find.ancestor(
            of: find.text('second'),
            matching: find.byType(SlideTransition),
          ),
        )
        .first;
    expect(incoming.position.value.dy, greaterThan(0));

    await tester.pumpAndSettle();
    final settled = tester
        .widgetList<SlideTransition>(
          find.ancestor(
            of: find.text('second'),
            matching: find.byType(SlideTransition),
          ),
        )
        .first;
    expect(settled.position.value, Offset.zero);
  });
}
