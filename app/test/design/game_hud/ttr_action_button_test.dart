import 'package:app/design/game_hud/ttr_action_button.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows the action label', (tester) async {
    await tester.pumpWidget(
      wrap(TtrActionButton(label: 'JUMP', onPressed: () {})),
    );

    expect(find.text('JUMP'), findsOneWidget);
  });

  testWidgets('fires onPressed on tap-DOWN (not tap-up)', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      wrap(TtrActionButton(label: 'DASH', onPressed: () => fired++)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TtrActionButton)),
    );
    await tester.pump();
    expect(fired, 1);

    await gesture.up();
    await tester.pump();
    expect(fired, 1, reason: 'release must not fire again');
  });

  testWidgets('disabled button never fires', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      wrap(
        TtrActionButton(
          label: 'JUMP',
          onPressed: () => fired++,
          enabled: false,
        ),
      ),
    );

    await tester.press(find.byType(TtrActionButton));
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('fires onReleased on pointer up and cancel', (tester) async {
    var released = 0;
    await tester.pumpWidget(
      wrap(
        TtrActionButton(
          label: 'JUMP',
          onPressed: () {},
          onReleased: () => released++,
        ),
      ),
    );

    final center = tester.getCenter(find.byType(TtrActionButton));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(released, 0, reason: 'press-down must not release');

    await gesture.up();
    await tester.pump();
    expect(released, 1);

    final second = await tester.startGesture(center);
    await second.cancel();
    await tester.pump();
    expect(released, 2, reason: 'cancel counts as release');
  });

  testWidgets('enabled button uses the token primary fill', (tester) async {
    await tester.pumpWidget(
      wrap(TtrActionButton(label: 'JUMP', onPressed: () {})),
    );

    final fills = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color);
    expect(fills, contains(ColorPalette.primary));
  });
}
