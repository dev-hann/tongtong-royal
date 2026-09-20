// § 11.2 case 3 — system back during a show round opens the quit
// dialog; KEEP RUNNING resumes the round.
//
// Anchor note: the dialog title widget string is 'Quit the race?'
// (question mark included) — ttr_quit_dialog.dart line 40.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'quit_dialog_keep_running_resumes_race',
    ($) async {
      // Arrange: in play (guard + PLAY SOLO + countdown included).
      await helpers.reachShowPlay($);

      // Act: system back (native — § 11.1 sanctioned interaction).
      await $.native.pressBack();

      // Assert 1: confirm dialog shows (§ 9 anchor, exact text).
      await $.waitUntilVisible(
        find.text('Quit the race?'),
        timeout: const Duration(seconds: 10),
      );

      // Act 2: dismiss without quitting.
      await $.tap(find.text('KEEP RUNNING'));

      // Assert 2: back in the race — control visible again.
      await $.waitUntilVisible(
        find.text('JUMP'),
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
