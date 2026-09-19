import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGroup(
    WidgetTester tester, {
    String? label = 'IDENTITY',
    int? staggerIndex,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TtrCardGroup(
            label: label,
            staggerIndex: staggerIndex,
            children: const [Text('row-a'), Text('row-b')],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder decoratedGroup() => find
      .descendant(
        of: find.byType(TtrCardGroup),
        matching: find.byType(Container),
      )
      .first;

  testWidgets('renders the section label uppercased in label style', (
    tester,
  ) async {
    await pumpGroup(tester, label: 'identity');

    final label = tester.widget<Text>(find.text('IDENTITY'));
    expect(label.style?.color, ColorPalette.neutral500);
    expect(label.style?.fontFamily, FontTokens.display);
    expect(label.style?.letterSpacing, TypeScale.labelTracking);
    expect(
      label.textAlign,
      isNot(TextAlign.center),
      reason: 'section labels are left-aligned (guide § 6 FORM)',
    );
  });

  testWidgets('omits the label when none is given', (tester) async {
    await pumpGroup(tester, label: null);

    expect(find.text('IDENTITY'), findsNothing);
    expect(find.text('row-a'), findsOneWidget);
  });

  testWidgets('renders children inside a bordered surface container', (
    tester,
  ) async {
    await pumpGroup(tester);

    final card = tester.widget<Container>(decoratedGroup());
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, ColorPalette.surface);
    expect(decoration.borderRadius, BorderRadius.circular(RadiusScale.card));
    expect(decoration.border?.top.color, ColorPalette.neutral200);
    expect(decoration.border?.top.width, SpacingScale.xs);

    expect(
      find.descendant(
        of: decoratedGroup(),
        matching: find.text('row-a'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: decoratedGroup(), matching: find.text('row-b')),
      findsOneWidget,
    );
  });

  testWidgets('stretches children to the group width (guide § 6 actions)', (
    tester,
  ) async {
    await pumpGroup(tester);

    final cardWidth = tester.getSize(decoratedGroup()).width;
    final inner = cardWidth - 2 * (SpacingScale.md + SpacingScale.xs);
    expect(
      tester.getSize(find.text('row-a')).width,
      inner,
      reason: 'Text spans the stretched content box',
    );
  });

  testWidgets('wraps the group in a staggered entrance per index', (
    tester,
  ) async {
    await pumpGroup(tester, staggerIndex: 2);

    final entrance = tester.widget<TtrStaggeredEntrance>(
      find.descendant(
        of: find.byType(TtrCardGroup),
        matching: find.byType(TtrStaggeredEntrance),
      ),
    );
    expect(entrance.index, 2);
  });

  testWidgets('staggers nothing without a staggerIndex', (tester) async {
    await pumpGroup(tester);

    expect(
      find.descendant(
        of: find.byType(TtrCardGroup),
        matching: find.byType(TtrStaggeredEntrance),
      ),
      findsNothing,
    );
  });
}
