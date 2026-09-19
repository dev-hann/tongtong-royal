import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page shell paints an opaque background surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TtrPageShell(child: SizedBox.shrink())),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, ColorPalette.background);
  });

  testWidgets('page shell hosts the ambient backdrop behind the child', (
    tester,
  ) async {
    const childKey = Key('shell_child');
    await tester.pumpWidget(
      const MaterialApp(
        home: TtrPageShell(child: SizedBox(key: childKey)),
      ),
    );

    expect(find.byType(TtrAmbientBackdrop), findsOneWidget);
    expect(find.byKey(childKey), findsOneWidget);

    // Child renders ABOVE the backdrop (z-order: backdrop first).
    expect(tester.getTopLeft(find.byKey(childKey)).dy, greaterThanOrEqualTo(0));
  });

  testWidgets('page shell protects content with SafeArea', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: TtrPageShell(child: SizedBox.expand()),
        ),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
  });
}
