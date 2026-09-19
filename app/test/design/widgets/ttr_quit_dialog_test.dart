import 'dart:async' show unawaited;

import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_quit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final BuildContext context = tester.element(find.byType(Scaffold));
    // The dialog future resolves only on pop; the harness just needs
    // the dialog visible.
    unawaited(
      showDialog<bool>(context: context, builder: (_) => const TtrQuitDialog()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('actions fill the dialog width evenly (no right clustering)', (
    tester,
  ) async {
    await pumpDialog(tester);

    final quit = tester.getRect(find.byKey(TtrQuitDialog.confirmButtonKey));
    final keep = tester.getRect(
      find.byKey(TtrQuitDialog.keepRunningButtonKey),
    );

    // Same row, equal widths (guide § 5 dialog actions rule).
    expect(quit.height, keep.height);
    expect(quit.width, keep.width);
    // The pair spans the content width: the gap between buttons is
    // small compared to either button (not clustered at the right).
    final gap = keep.left - quit.right;
    expect(gap, lessThan(quit.width));
    // The left button starts near the dialog's left content edge.
    final dialog = tester.getRect(find.byKey(TtrQuitDialog.dialogKey));
    expect(quit.left - dialog.left, lessThan(quit.width));
  });

  testWidgets('quit button is secondary, keep-running is primary', (
    tester,
  ) async {
    await pumpDialog(tester);

    final quit = tester.widget<TtrButton>(
      find.byKey(TtrQuitDialog.confirmButtonKey),
    );
    final keep = tester.widget<TtrButton>(
      find.byKey(TtrQuitDialog.keepRunningButtonKey),
    );

    expect(quit.variant, TtrButtonVariant.secondary);
    expect(keep.variant, TtrButtonVariant.primary);
  });
}
