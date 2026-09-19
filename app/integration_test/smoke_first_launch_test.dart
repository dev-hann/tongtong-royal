// § 11.2 case 1 — first launch lands on Home.
//
// Device-state caveat: patrol cannot uninstall/reinstall the app
// under test from inside a test, so whether onboarding appears
// depends on the rig's persisted data. BOTH branches must satisfy
// the same hard assert (PLAY SOLO visible): the SKIP path is only
// exercised on a genuinely cold device.
import 'package:app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'first_launch_lands_on_home',
    ($) async {
      // Arrange: cold start (or persisted-profile start — both valid).
      app.main();
      // Never pumpAndSettle — ambient loops never settle (§ 11.1).
      try {
        await $.waitUntilVisible(
          find.text('SKIP'),
          // 10 s: cold start + profile store load on the slow rig.
          timeout: const Duration(seconds: 10),
        );
        // Act (branch A — onboarding shown): SKIP to Home.
        await $.tap(find.text('SKIP'));
      } on PatrolTimeoutException {
        // Branch B — already onboarded: Home comes up directly.
      }

      // Assert: Home visible either way (§ 9 anchor).
      await $.waitUntilVisible(
        find.text('PLAY SOLO'),
        // 20 s: first-frame profile load + transition (spike-proven).
        timeout: const Duration(seconds: 20),
      );
    },
  );
}
