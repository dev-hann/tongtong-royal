// § 11.2 case 2 — solo match: intro rule line, countdown into
// play, three jumps, race still running.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'solo_match_intro_then_three_jumps_keep_race_running',
    ($) async {
      // Arrange: on Home (own onboarding guard — case independence).
      await helpers.reachHome($);

      // Act: start a solo match. noSettle — the default tap settle
      // pumps past the 3 s intro countdown (see helpers.reachPlay).
      await $.tap(
        find.text('PLAY SOLO'),
        settlePolicy: SettlePolicy.noSettle,
      );

      // Assert 1: intro shows the rule line (§ 9 anchor).
      await $.waitUntilVisible(
        find.text('First to the finish line'),
        // 30 s: generous for match planning + phase transition.
        timeout: const Duration(seconds: 30),
      );

      // Assert 2: countdown (3 s, GDD § 5) ends in play — the
      // one-button control is visible.
      await $.waitUntilVisible(
        find.text('JUMP'),
        // 30 s budget for a 3 s countdown: absorbs Forge2D load and
        // transitions on the low-fps rig.
        timeout: const Duration(seconds: 30),
      );

      // Act 2: three jumps, spaced by bounded frame pumps (no
      // sleep/Future.delayed — Law § 10.2.5). noSettle keeps the
      // pacing in the test's own bounded pumps.
      for (var jump = 0; jump < 3; jump++) {
        await $.tap(
          find.text('JUMP'),
          settlePolicy: SettlePolicy.noSettle,
        );
        await $.pump(const Duration(milliseconds: 500));
      }

      // Assert 3: race still running — control still visible.
      await $.waitUntilVisible(
        find.text('JUMP'),
        timeout: const Duration(seconds: 5),
      );
    },
  );
}
