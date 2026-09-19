# 09 — UX Checklist

Usability criteria for every user-facing change. Joins the compliance review gate (AGENTS § 10): each item is checkable and violations are review findings. Visual style rules live in `docs/07-design-guide.md`; this document is about *behavior and navigation*.

---

## 1. Navigation & Escape (every screen)

- [ ] **Back affordance**: every pushed route shows a top-left back control (`TtrBackButton`) — immersive mode hides the system bar, gestures cannot be the only way back.
- [ ] **Back matrix is explicit**:
  | Context | System back / gesture does |
  |---------|----------------------------|
  | Home | default app exit |
  | Pushed route (Profile/Settings/Credits) | pop the route |
  | ROUND_PLAY | quit-confirm dialog (never silent app exit) |
  | ROUND_RESULTS | go HOME |
  | Onboarding (first launch) | default app exit (no route stack yet) |
- [ ] **No trapped states**: from any screen, the user can reach Home within ≤ 2 interactions without killing the app. Long-running flows (a race) expose an explicit exit with a confirm dialog (`TtrQuitDialog`).
- [ ] **Destructive actions confirm**: quit mid-race, anything that discards progress → dialog with clear verbs (QUIT / KEEP RUNNING).

## 2. Inputs & Forms

- [ ] Nickname-style fields (names, not words): `spellCheckConfiguration: SpellCheckConfiguration.disabled()` — red squiggles under names are noise.
- [ ] Input limits stated in UI (helper text) and enforced (validation + fallback).
- [ ] Onboarding is skippable; skipped defaults remain editable later via Profile.

## 3. Screens & Surfaces

- [ ] Pushed screens use `TtrPageShell` (opaque token background + ambient + SafeArea). A bare `Stack(backdrop, ...)` route renders the black route barrier wherever decorative shapes don't cover — forbidden.
- [ ] Content respects SafeArea (display cutouts); bottom-anchored controls add `viewPadding.bottom`.
- [ ] Bottom-dwell controls (JUMP button) never overlap top-dwell affordances (quit/back) — corners are owned.

## 4. System Chrome & Orientation

- [ ] Portrait lock is enforced **twice**: `AndroidManifest.xml` `android:screenOrientation="portrait"` (survives activity recreation — foldables, cover displays) AND Dart-side `setPreferredOrientations` re-asserted on every app resume (fold state changes recreate activities and drop Dart-side requests).
- [ ] Immersive sticky re-applied on resume (same reason).

## 5. Feedback & State

- [ ] Every async action with visible latency shows progress or a disabled-while-working control.
- [ ] Errors surface as `TtrToast` or dialog text — never silently swallowed (AGENTS § 6.5).
- [ ] Stats/persistence side effects fire exactly once per user-visible event (e.g. results recorded once).

## 6. Typography on Device (recurrence rules)

- [ ] Fonts ship as **static weight instances** mapped in pubspec — variable-font TTFs are forbidden: Flutter does not drive the `wght` axis from `fontWeight` (issue 74643), so hierarchy collapses to the default weight. Incident 2026-09-19.
- [ ] Icon glyphs come from `TtrIcons` (Phosphor Fill). Verify codepoints against the package source before adding — guessed codepoints render wrong glyphs.
