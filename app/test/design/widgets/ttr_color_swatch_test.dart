import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_color_swatch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders the palette color with the primary ring when selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const TtrColorSwatch(color: PlayerPalette.two, selected: true)),
    );

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, PlayerPalette.two);
    expect(decoration.border?.top.color, ColorPalette.primary);
  });

  testWidgets(
    'unselected swatch carries a surface hairline instead of a ring',
    (tester) async {
      await tester.pumpWidget(
        wrap(const TtrColorSwatch(color: PlayerPalette.three, selected: false)),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border!.top.width, lessThan(4));
      expect(decoration.border?.top.color, ColorPalette.surface);
    },
  );

  testWidgets('fires onTap with the 56px touch target (guide § 8)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        TtrColorSwatch(
          color: PlayerPalette.one,
          selected: false,
          onTap: () => taps++,
        ),
      ),
    );

    expect(tester.getSize(find.byType(TtrColorSwatch)), const Size(56, 56));

    await tester.tap(find.byType(TtrColorSwatch));
    await tester.pump();
    expect(taps, 1);
  });
}
