// § 11.2 case 5 — race finish: results show placements, PLAY
// AGAIN restarts the intro. Single flow — the HOME-return path is
// case 4's territory (smoke_quit_to_home).
//
// Seed note (§ 11.1 determinism): the shell seeds each match from
// the wall clock (shell_scaffold.dart), which is not injectable
// from a Patrol test; the race outcome is therefore NOT asserted —
// only that SOME placement renders.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart' as helpers;

void main() {
  patrolTest(
    'race_finish_shows_placements_and_play_again_restarts_intro',
    // Whole-case ceiling: round cap 90 s (trap_race timeoutMs) +
    // results resolution + restart must fit comfortably below the
    // 10 min testWidgets default; 6 min leaves triage headroom.
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      // Arrange: in play (guard + PLAY SOLO + countdown included).
      await helpers.reachPlay($);

      // Act: let the round play out. trap_race ends on completion
      // or its 90 s timeout; resolution then flips ROUND_RESULTS.
      // 150 s = 90 s cap + transition/resolution margin on the
      // low-fps rig. No sleeps — the wait pumps while polling.
      await $.waitUntilVisible(
        find.text('PLAY AGAIN'),
        timeout: const Duration(seconds: 150),
      );

      // Assert 1: placements list rendered — the winner's rank
      // ordinal is visible. Same finish tick shares the rank (GDD
      // § 7.6) and renders 'T-1st', so accept exactly one of the
      // two labels (never both on one screen).
      var winnerRankVisible = false;
      try {
        await $.waitUntilVisible(
          find.text('1st'),
          timeout: const Duration(seconds: 5),
        );
        winnerRankVisible = true;
      } on PatrolTimeoutException {
        await $.waitUntilVisible(
          find.text('T-1st'),
          timeout: const Duration(seconds: 5),
        );
        winnerRankVisible = true;
      }
      expect(
        winnerRankVisible,
        isTrue,
        reason: 'results must render a winner rank (1st or T-1st)',
      );

      // Act 2: restart. noSettle — the default tap settle pumps
      // through the fresh intro countdown before it is assertable.
      await $.tap(
        find.text('PLAY AGAIN'),
        settlePolicy: SettlePolicy.noSettle,
      );

      // Assert 2: fresh match restarts at the intro rule line.
      await $.waitUntilVisible(
        find.text('First to the finish line'),
        timeout: const Duration(seconds: 30),
      );
    },
  );
}
