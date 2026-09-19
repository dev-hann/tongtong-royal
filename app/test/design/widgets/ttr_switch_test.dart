import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
import 'package:app/design/widgets/ttr_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );

  Finder scaleOf() => find.descendant(
    of: find.byType(TtrPressScale),
    matching: find.byType(ScaleTransition),
  );

  BoxDecoration trackOf(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
              .decoration!
          as BoxDecoration;

  BoxDecoration thumbOf(WidgetTester tester) =>
      tester.widget<Container>(find.byType(Container).last).decoration!
          as BoxDecoration;

  testWidgets('tap fires onChanged with the flipped value', (tester) async {
    var current = true;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => TtrSwitch(
            value: current,
            onChanged: (value) => setState(() => current = value),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TtrSwitch));
    await tester.pump();

    expect(current, isFalse);
  });

  testWidgets('visuals flip per state: track primary vs neutral200', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(TtrSwitch(value: true, onChanged: (_) {})));
    expect(trackOf(tester).color, ColorPalette.primary);

    await tester.pumpWidget(wrap(TtrSwitch(value: false, onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(trackOf(tester).color, ColorPalette.neutral200);
  });

  testWidgets('thumb is surface with a chunky neutral900 border', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(TtrSwitch(value: true, onChanged: (_) {})));

    final thumb = thumbOf(tester);
    expect(thumb.color, ColorPalette.surface);
    expect(thumb.border?.top.color, ColorPalette.neutral900);
    expect(thumb.border?.top.width, SpacingScale.xs);
  });

  testWidgets('press scale feedback wraps the control', (tester) async {
    await tester.pumpWidget(wrap(TtrSwitch(value: true, onChanged: (_) {})));

    expect(
      find.descendant(of: find.byType(TtrSwitch), matching: scaleOf()),
      findsOneWidget,
    );
  });

  testWidgets('thumb slides between track ends', (tester) async {
    await tester.pumpWidget(wrap(TtrSwitch(value: false, onChanged: (_) {})));
    var alignment =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
                .alignment
            as Alignment?;
    expect(alignment, Alignment.centerLeft);

    await tester.pumpWidget(wrap(TtrSwitch(value: true, onChanged: (_) {})));
    await tester.pumpAndSettle();
    alignment =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
                .alignment
            as Alignment?;
    expect(alignment, Alignment.centerRight);
  });
}
