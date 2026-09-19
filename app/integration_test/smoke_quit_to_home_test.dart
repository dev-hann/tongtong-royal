// § 11.2 case 4 — system back during a race, then QUIT: the match
// is abandoned and Home is visible with the app process alive
// (a responding widget tree IS the alive proof).
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'quit_dialog_confirm_returns_home',
    ($) async {
      // Arrange: in play (guard + PLAY SOLO + countdown included).
      await helpers.reachPlay($);

      // Act: system back, then confirm the quit.
      await $.native.pressBack();
      await $.waitUntilVisible(
        find.text('Quit the race?'),
        timeout: const Duration(seconds: 10),
      );
      await $.tap(find.text('QUIT'));

      // Assert: Home visible (§ 9 anchor) — tree still responds,
      // so the process is alive.
      await $.waitUntilVisible(
        find.text('PLAY SOLO'),
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
