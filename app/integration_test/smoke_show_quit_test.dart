// v2 standing case — abandon a show mid-round (GDD v2 § 7.4 /
// docs/03 § 11.2): system back during ROUND 1 opens the quit
// confirm; QUIT abandons the show (no stats recorded) and Home is
// visible with the app process alive (a responding widget tree IS
// the alive proof). Replaces the v1 quit_to_home case.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'show_quit_confirm_returns_home',
    ($) async {
      // Arrange: in ROUND 1 play (guard + PLAY SOLO + countdown).
      await helpers.reachShowPlay($);

      // Act: system back (native — § 11.1 sanctioned interaction),
      // then confirm the abandon.
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
