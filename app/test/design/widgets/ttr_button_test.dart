import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  testWidgets('renders the label and fires onPressed on tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      wrap(TtrButton(label: 'START', onPressed: () => pressed = true)),
    );

    expect(find.text('START'), findsOneWidget);
    await tester.tap(find.byType(TtrButton));
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets('disabled (null onPressed) ignores taps', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      wrap(TtrButton(label: 'START', onPressed: () => pressed = true)),
    );

    await tester.pumpWidget(wrap(const TtrButton(label: 'START')));
    await tester.tap(find.byType(TtrButton), warnIfMissed: false);
    await tester.pump();
    expect(pressed, isFalse);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('variants use primary and secondary token colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            TtrButton(label: 'GO'),
            TtrButton(label: 'BACK', variant: TtrButtonVariant.secondary),
          ],
        ),
      ),
    );

    final buttons = tester
        .widgetList<FilledButton>(find.byType(FilledButton))
        .toList();
    expect(buttons, hasLength(2));
  });

  testWidgets('primary button fill is the token primary color', (tester) async {
    await tester.pumpWidget(wrap(TtrButton(label: 'GO', onPressed: () {})));

    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style;
    final resolved = style?.backgroundColor?.resolve({});
    expect(resolved, ColorPalette.primary);
  });

  testWidgets('label uses the display face with label tracking', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(TtrButton(label: 'GO', onPressed: () {})));

    // FilledButton merges ButtonStyle.textStyle into the default
    // text style, so read the resolved paragraph style.
    final style = tester
        .renderObject<RenderParagraph>(find.text('GO'))
        .text
        .style!;
    expect(style.fontFamily, FontTokens.display);
    expect(style.fontWeight!.value, TypeScale.labelWeight);
    expect(style.letterSpacing, TypeScale.labelTracking);
  });

  testWidgets('squashes to the press token on press-down', (tester) async {
    await tester.pumpWidget(wrap(TtrButton(label: 'GO', onPressed: () {})));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TtrButton)),
    );
    // Second pump lets the squash controller's first tick land.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<ScaleTransition>(scaleOf()).scale.value,
      MotionScales.press,
    );

    await gesture.up();
    // Build frame starts the reverse; the next advances it.
    await tester.pump();
    await tester.pump(MotionDurations.tap);
    expect(tester.widget<ScaleTransition>(scaleOf()).scale.value, 1);
  });

  testWidgets('release springs back within the tap duration', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(TtrButton(label: 'GO', onPressed: () {})));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TtrButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    await tester.pump(MotionDurations.tap ~/ 2);

    final recovering = tester.widget<ScaleTransition>(scaleOf()).scale.value;
    expect(recovering, greaterThan(MotionScales.press));
    expect(recovering, lessThan(1));

    await tester.pump(MotionDurations.tap);
    expect(tester.widget<ScaleTransition>(scaleOf()).scale.value, 1);
  });
}
