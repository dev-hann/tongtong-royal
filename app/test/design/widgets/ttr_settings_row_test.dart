import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
import 'package:app/design/widgets/ttr_settings_row.dart';
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

  testWidgets('renders leading icon, title, subtitle and trailing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Credits',
          subtitle: 'Fonts and asset attribution',
          trailing: Icon(TtrIcons.caretRight),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(TtrIcons.bookOpen));
    expect(icon.color, ColorPalette.neutral700);
    expect(icon.size, 24);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('Fonts and asset attribution'), findsOneWidget);
    expect(find.byIcon(TtrIcons.caretRight), findsOneWidget);
  });

  testWidgets('subtitle is optional', (tester) async {
    await tester.pumpWidget(
      wrap(const TtrSettingsRow(leading: TtrIcons.bookOpen, title: 'Credits')),
    );

    expect(find.text('Credits'), findsOneWidget);
  });

  testWidgets('onTap fires on row tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Credits',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(TtrSettingsRow));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('row without onTap ignores taps', (tester) async {
    var switched = false;
    await tester.pumpWidget(
      wrap(
        TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Sound',
          trailing: TtrSwitch(value: false, onChanged: (_) => switched = true),
        ),
      ),
    );

    await tester.tap(find.text('Sound'), warnIfMissed: false);
    await tester.pump();

    expect(switched, isFalse);
  });

  testWidgets('press scale feedback wraps the row', (tester) async {
    await tester.pumpWidget(
      wrap(
        TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Credits',
          onTap: () {},
        ),
      ),
    );

    expect(
      find.descendant(of: find.byType(TtrSettingsRow), matching: scaleOf()),
      findsOneWidget,
    );
  });

  testWidgets('card uses surface fill, neutral900 border, card radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Credits',
          onTap: () {},
        ),
      ),
    );

    final decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
            as BoxDecoration;
    expect(decoration.color, ColorPalette.surface);
    expect(decoration.border?.top.color, ColorPalette.neutral900);
    expect(decoration.border?.top.width, SpacingScale.xs);
    expect(decoration.borderRadius, BorderRadius.circular(RadiusScale.card));
  });

  testWidgets('row meets the 56px touch target (guide § 8)', (tester) async {
    await tester.pumpWidget(
      wrap(
        TtrSettingsRow(
          leading: TtrIcons.bookOpen,
          title: 'Credits',
          subtitle: 'Fonts and asset attribution',
          onTap: () {},
        ),
      ),
    );

    final size = tester.getSize(find.byType(TtrSettingsRow));
    expect(size.height, greaterThanOrEqualTo(56));
  });
}
