import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders the label and fires onPressed on tap', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      wrap(TtrButton(label: 'Start', onPressed: () => pressed = true)),
    );

    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.byType(TtrButton));
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets('disabled (null onPressed) ignores taps', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      wrap(TtrButton(label: 'Start', onPressed: () => pressed = true)),
    );

    await tester.pumpWidget(wrap(const TtrButton(label: 'Start')));
    await tester.tap(find.byType(TtrButton), warnIfMissed: false);
    await tester.pump();
    expect(pressed, isFalse);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('variants use primary and secondary token colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            TtrButton(label: 'A'),
            TtrButton(label: 'B', variant: TtrButtonVariant.secondary),
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
    await tester.pumpWidget(wrap(TtrButton(label: 'Go', onPressed: () {})));

    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style;
    final resolved = style?.backgroundColor?.resolve({});
    expect(resolved, ColorPalette.primary);
  });
}
