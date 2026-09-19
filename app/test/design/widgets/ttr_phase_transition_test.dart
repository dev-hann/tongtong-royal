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
}
