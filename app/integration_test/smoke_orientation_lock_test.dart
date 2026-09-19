// § 11.2 case 8 — orientation lock (portrait enforced).
//
// PLATFORM LIMITATION (documented best-effort, per § 11.2 note):
// patrol 3.20.0 exposes NO native rotate command (verified against
// the package source: NativeAutomator has pressBack/tap/swipe/
// enterText only), and the enrolled rig (LineageOS Pi 4 over HDMI)
// has no accelerometer to drive a sensor rotation. A rotation
// attempt therefore cannot be issued from inside the test.
//
// Degraded assertion: the lock's observable steady state — main.dart
// pins portraitUp at launch and on every resume
// (shell_scaffold.dart), so the case asserts Home keeps rendering
// its portrait layout (PLAY SOLO visible) after launch settles.
// When a rotate API lands (patrol upgrade) or an accelerometer
// device is enrolled, extend this case to drive the rotation first.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'orientation_lock_portrait_home_still_renders',
    ($) async {
      // Arrange + Act: launch through the guard; portraitUp is
      // applied before the first frame (main.dart).
      await helpers.reachHome($);

      // Assert: portrait steady state — Home's primary CTA visible.
      await $.waitUntilVisible(
        find.text('PLAY SOLO'),
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
