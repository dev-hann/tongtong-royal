// v2 standing case — full show happy path (docs/03 § 11.2): start a
// show, play ROUND 1 (tapping JUMP to help the auto-runner), watch
// the qualifier flash verdicts, then either chain ROUND 2 → FINAL →
// crown podium (qualified) or land on the elimination summary (out
// mid-show, GDD v2 § 7.3). Both terminals end in PLAY AGAIN, which
// must restart the show at the ROUND 1 intro.
//
// Determinism note (§ 11.1): the show seed is wall-clock, so the
// HUMAN's own verdict is never asserted — the case asserts the flow
// shape (pill → play → flash verdicts → terminal) and, whenever the
// human qualifies, the deeper chain through the crown podium.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

/// Polls [candidates] until one shows up or [deadline] passes.
/// Polling uses sanctioned `waitUntilVisible` short waits — no
/// sleeps (Law § 10.2.5).
Future<bool> _anyVisible(
  PatrolIntegrationTester $,
  List<Finder> candidates,
  Duration deadline,
) async {
  final end = DateTime.now().add(deadline);
  while (DateTime.now().isBefore(end)) {
    for (final candidate in candidates) {
      try {
        await $.waitUntilVisible(
          candidate,
          timeout: const Duration(seconds: 2),
        );
        return true;
      } on PatrolTimeoutException {
        // Not this one — keep polling.
      }
    }
  }
  return false;
}

void main() {
  patrolTest(
    'show_happy_path_chains_rounds_and_ends_crown_terminal',
    // Whole-case ceiling: R1 race cap 90 s + R2 hammer cap 60 s +
    // FINAL cap 60 s + three 4 s flashes + three 3 s intros. On the
    // low-fps rig the fixed-dt sim runs slower than wall-clock
    // (backlog clamps), so every cap budget carries ~2x headroom;
    // 14 min stays under the 15 min patrol ceiling.
    timeout: const Timeout(Duration(minutes: 14)),
    ($) async {
      // Arrange: in ROUND 1 play (guard + PLAY SOLO + countdown).
      await helpers.reachShowPlay($);

      // Act 1: help the auto-runner through the gaps — periodic
      // bounded-pump taps (no sleeps).
      for (var i = 0; i < 8; i++) {
        await $.tap(
          find.text('JUMP'),
          settlePolicy: SettlePolicy.noSettle,
        );
        await $.pump(const Duration(milliseconds: 600));
      }

      // Assert 1: ROUND 1 ends in a qualifier flash — some verdict
      // chip is visible (§ 9 anchors). 240 s = 90 s cap at up to
      // ~2x wall-clock drag on the rig + margins.
      var flashed = await _anyVisible(
        $,
        [find.text('QUALIFIED'), find.text('ELIMINATED')],
        const Duration(seconds: 240),
      );
      expect(flashed, isTrue, reason: 'ROUND 1 must reach a flash');

      // Assert 2: 4 s flash ends in either the ROUND 2 intro
      // (human qualified) or the elimination summary terminal.
      final chained = await _anyVisible(
        $,
        [find.text('ROUND 2 / 3'), find.text('PLAY AGAIN')],
        const Duration(seconds: 30),
      );
      expect(chained, isTrue, reason: 'flash must advance the show');

      final reachedRoundTwo = await _anyVisible(
        $,
        [find.text('ROUND 2 / 3')],
        const Duration(seconds: 2),
      );

      if (reachedRoundTwo) {
        // Hammer Dodge round: JUMP returns; idle on the spawn slab
        // is safe, the round closes by quota or its 60 s timeout.
        await $.waitUntilVisible(
          find.text('Last two standing qualify'),
          timeout: const Duration(seconds: 10),
        );
        await $.waitUntilVisible(
          find.text('JUMP'),
          timeout: const Duration(seconds: 30),
        );
        flashed = await _anyVisible(
          $,
          [find.text('QUALIFIED'), find.text('ELIMINATED')],
          const Duration(seconds: 150),
        );
        expect(flashed, isTrue, reason: 'ROUND 2 must reach a flash');

        // Flash leads to the FINAL intro or the summary terminal.
        final finalOrOut = await _anyVisible(
          $,
          [find.text('ROUND 3 / 3'), find.text('PLAY AGAIN')],
          const Duration(seconds: 30),
        );
        expect(finalOrOut, isTrue);

        final reachedFinal = await _anyVisible(
          $,
          [find.text('ROUND 3 / 3')],
          const Duration(seconds: 2),
        );
        if (reachedFinal) {
          // FINAL: the crown round — its flash IS the crown moment
          // (§ 9 anchor CROWN), whoever wins.
          await $.waitUntilVisible(
            find.text('First finisher takes the crown'),
            timeout: const Duration(seconds: 10),
          );
          await $.waitUntilVisible(
            find.text('JUMP'),
            timeout: const Duration(seconds: 30),
          );
          await $.waitUntilVisible(
            find.text('CROWN'),
            timeout: const Duration(seconds: 150),
          );
          // Podium ceremony: CROWN (bot won) or VICTORY (human won)
          // plus the two terminal actions.
          final crowned = await _anyVisible(
            $,
            [find.text('CROWN'), find.text('VICTORY')],
            const Duration(seconds: 30),
          );
          expect(crowned, isTrue, reason: 'podium must crown someone');
          await $.waitUntilVisible(
            find.text('HOME'),
            timeout: const Duration(seconds: 10),
          );
        }
      }

      // Act 2 + Assert: whichever terminal the show reached (podium
      // or elimination summary), PLAY AGAIN restarts at ROUND 1.
      await $.tap(
        find.text('PLAY AGAIN'),
        settlePolicy: SettlePolicy.noSettle,
      );
      await $.waitUntilVisible(
        find.text('ROUND 1 / 3'),
        timeout: const Duration(seconds: 30),
      );
    },
  );
}
