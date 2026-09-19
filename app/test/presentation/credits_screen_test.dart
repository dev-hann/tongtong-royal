import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/presentation/credits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists every bundled asset with license', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreditsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Fredoka font'), findsOneWidget);
    expect(find.text('Nunito font'), findsOneWidget);
    expect(find.text('Phosphor Icons (Fill)'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.textContaining('generated placeholders'), findsOneWidget);
    expect(find.textContaining('SIL OFL 1.1'), findsNWidgets(2));
    expect(find.textContaining('MIT'), findsOneWidget);
    expect(find.byKey(const Key('credits_row_Fredoka font')), findsOneWidget);
    expect(
      find.byKey(const Key('credits_row_Phosphor Icons (Fill)')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('credits_row_Sound effects')), findsOneWidget);
  });

  testWidgets('form law: fixed header over one assets card group', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreditsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TtrPageHeader), findsOneWidget);
    expect(find.byType(TtrCardGroup), findsOneWidget);
    expect(find.text('ASSETS'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TtrCardGroup),
        matching: find.text('Fredoka font'),
      ),
      findsOneWidget,
      reason: 'attribution rows live inside the card group',
    );
  });

  testWidgets('top-left back affordance pops the route', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator))
      ..push(MaterialPageRoute<void>(builder: (_) => const CreditsScreen()));
    await tester.pump();
    // Fixed pumps, not pumpAndSettle: the ambient backdrop animates
    // forever.
    await tester.pump(const Duration(milliseconds: 400));
    expect(navigator.canPop(), isTrue);

    await tester.tap(find.byKey(TtrBackButton.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(navigator.canPop(), isFalse);
  });
}
