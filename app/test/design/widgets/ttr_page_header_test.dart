import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    bool showBack = true,
    Widget? trailing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TtrPageHeader(
            title: 'PROFILE',
            showBack: showBack,
            trailing: trailing,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders the back affordance and the title', (tester) async {
    await pumpHeader(tester);

    expect(find.byKey(TtrBackButton.buttonKey), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
  });

  testWidgets('title renders in the title role centered on the screen', (
    tester,
  ) async {
    await pumpHeader(tester);

    final title = tester.widget<Text>(find.text('PROFILE'));
    expect(title.style, TypeScale.title);

    final header = tester.getSize(find.byType(TtrPageHeader));
    expect(tester.getCenter(find.text('PROFILE')).dx, header.width / 2);
  });

  testWidgets('hides the back affordance when showBack is false', (
    tester,
  ) async {
    await pumpHeader(tester, showBack: false);

    expect(find.byKey(TtrBackButton.buttonKey), findsNothing);
  });

  testWidgets('renders the trailing widget in the right header slot', (
    tester,
  ) async {
    const trailingKey = Key('trailing_probe');

    await pumpHeader(
      tester,
      trailing: const Text('SKIP', key: trailingKey),
    );

    expect(find.byKey(trailingKey), findsOneWidget);
    final headerRight = tester.getTopRight(find.byType(TtrPageHeader)).dx;
    expect(
      tester.getTopRight(find.byKey(trailingKey)).dx,
      lessThan(headerRight),
    );
  });
}
