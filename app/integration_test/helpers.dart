// Shared launch/navigation routines for the standing Patrol suite
// (docs/03 § 11.2). Every case must run alone (Law § 10.2.6), so
// the helpers only compose three things: app start, the device-
// state-proof onboarding guard, and entry to the play screen.
//
// Device data persists between runs on the enrolled rigs — whether
// onboarding appears is NOT controllable from inside a test, so
// every entry point goes through the guard below, which tolerates
// both states (first launch: SKIP; onboarded: straight to Home).
//
// NEVER pumpAndSettle here: ambient loops (backdrop drift, pulses)
// schedule frames forever — the tree does not settle (§ 11.1).
import 'package:app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Launches the app, passes the onboarding guard, and asserts Home
/// is visible (PLAY SOLO — docs/03 § 9 anchor).
///
/// The guard: first launch shows SKIP (tap it); an already-onboarded
/// device never shows it (PatrolTimeoutException is the expected
/// signal, not an error).
Future<void> reachHome(PatrolIntegrationTester $) async {
  app.main();
  try {
    // 10 s: cold app start + profile store load on the slow rig.
    await $.waitUntilVisible(
      find.text('SKIP'),
      timeout: const Duration(seconds: 10),
    );
    await $.tap(find.text('SKIP'));
  } on PatrolTimeoutException {
    // Already onboarded — Home is the next visible state.
  }
  // 20 s: covers first-frame profile load + phase transition on
  // the Pi rig (spike-proven duration).
  await $.waitUntilVisible(
    find.text('PLAY SOLO'),
    timeout: const Duration(seconds: 20),
  );
}

/// [reachHome] plus: start a solo match and wait until the round is
/// actually playable (JUMP visible). Covers the intro rule line and
/// the 3 s countdown (GDD § 5) with one generous budget.
Future<void> reachPlay(PatrolIntegrationTester $) async {
  await reachHome($);
  // noSettle: patrol's default tap settle (trySettle, up to 10 s of
  // pumps) burns straight through the 3 s intro countdown — the
  // rule line would never be observable. Waits stay explicit.
  await $.tap(
    find.text('PLAY SOLO'),
    settlePolicy: SettlePolicy.noSettle,
  );
  // Intro must show the rule line (§ 9 anchor) before countdown.
  await $.waitUntilVisible(
    find.text('First to the finish line'),
    timeout: const Duration(seconds: 30),
  );
  // 30 s budget for a 3 s countdown: absorbs phase transitions on
  // a device that renders Forge2D at low fps.
  await $.waitUntilVisible(
    find.text('JUMP'),
    timeout: const Duration(seconds: 30),
  );
}
