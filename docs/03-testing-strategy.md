# 03 — Testing Strategy

TDD is the development model, not an afterthought. Procedure and cycle live in `AGENTS.md` § 4; this document defines *what* to test, *where*, and the quality bars.

---

## 1. Test Pyramid

| Level | Target | Tooling | Gate |
|-------|--------|---------|------|
| Unit | `shared/domain`, `shared/physics`, `shared/protocol` | `package:test` | ≥ 90% line coverage, enforced in CI |
| Unit | `server/` (rooms, relay, validation) | `package:test` | ≥ 85% |
| Physics (headless) | `app/game` simulation behaviors | Forge2D stepping in pure Dart test | Core scenarios (§ 4) all present |
| Widget | `app/presentation` shell screens | `flutter_test` | Main screens have smoke + state tests |
| Integration | client ↔ server over in-process WS | `server` + fake client | One E2E: room create → match complete → podium |

Coverage is a **floor, not a goal**. Tests exist to verify behavior; padding coverage with noise is a test smell (§ 6) and a review-blocker.

## 2. Red-Green-Refactor, Concretely

1. **Red** — write the test. Run it. It must fail with an *assertion* failure or the *expected missing-symbol* error, proving the test exercises the new behavior. A test failing because of a typo, wrong import, or unrelated crash does not count as Red; fix the test.
2. **Green** — minimum implementation to pass. No speculative features "while you're in there".
3. **Refactor** — improve names, extract duplication, apply architecture doc rules. Tests stay green. This phase is mandatory: shipping the first working draft of the implementation is forbidden.

## 3. Behavior Verification Principle

Every test must verify **observable behavior through a public API**: inputs → outputs/events. Allowed outputs: return values, emitted domain events, state transitions.

Required in every rule-level test suite:

- **Boundary values**: 0 players, 1 player, 4 players, exactly-at-timeout.
- **Failure paths**: empty events, missing player, malformed round data.
- **The spec's edge cases**: every item in `docs/01-game-design.md` § 7 has at least one named test (`gdd_7_4_race_timeout_ranks_by_distance`, etc.). An untested GDD edge case is an open defect.

## 4. Physics Testing Pattern (headless)

Forge2D is pure Dart — tests step the world manually:

```dart
test('dash cannot exceed maxLinearVelocity', () {
  final sim = TestSimulation.build();       // fixed map, seeded
  sim.spawnPlayer(id: 1, at: spawnPoint);
  sim.input(1, dashLeft);
  for (var i = 0; i < 300; i++) {
    sim.step();                              // fixed dt from PhysicsConsts
  }
  expect(sim.velocityOf(1).length, lessThan(PhysicsConsts.maxLinearVelocity));
});
```

Rules:

- **Never** use real time (`Future.delayed`, wall clock) in physics tests.
- Fixed dt from `shared/physics` — the same constant the game uses.
- Seeded randomness only (map seed in test fixture).
- Core scenarios that must always exist: tunneling (thin wall + max-speed dash), NaN guard (zero-mass/overlap abuse → respawn), stuck detection (input + no displacement → respawn), checkpoint respawn order.

## 5. Protocol Tests (roundtrip, exhaustive)

Every message type in `shared/protocol`:

```dart
test('PlayerInput roundtrips', () {
  final msg = PlayerInput(tick: 42, seq: 7, move: Vector2(0.5, 0), jump: true);
  expect(PlayerInput.fromJson(msg.toJson()), msg);
});
```

Plus one rejection test per message: malformed payload must throw `ProtocolException`, never crash silently.

## 6. Test Smells (catalog — violation blocks merge)

| Smell | Example | Fix |
|-------|---------|-----|
| Testing implementation details | `expect(controller._buffer.length, 3)` | Assert observable outcome instead |
| Coverage padding | `expect(consts.jumpImpulse, consts.jumpImpulse)` | Delete; write a behavior test |
| Asserting on mocks | "mock was called with X" as the *only* assertion | Mocks arrange, real assertions verify outcomes |
| Mock overload in domain tests | Mocking anything inside `shared/domain` tests | Domain is pure — it needs no mocks. Needing one is a design alarm; refactor |
| Snapshot-everything | Golden tests as primary coverage | Goldens for critical visuals only |
| Testing around the code | Writing the test to match whatever the code does | Test the spec (GDD), not the implementation |
| Shared mutable fixtures | Tests pass alone, fail together | Fresh fixture per test |
| Time-dependent flakiness | `Future.delayed` in assertions | Inject a clock / step manually |

## 7. Integration Test (single E2E, in-process)

Scope: create room → join 3 fake clients → ready → 1 short round → results → podium.

- Server runs in-process (no network beyond loopback WS).
- Clients are fake drivers: they send inputs at fixed intervals; one is designated host and runs the real simulation headlessly.
- Asserts: room state transitions, snapshot flow, final placements match domain's resolution of emitted events, disconnect grace behavior.

## 8. CI Gates

On every push/PR: `dart analyze` (zero warnings), `dart test` (all green), coverage ≥ floor for `shared/`. CI configuration: `.github/workflows/ci.yml`. Red CI blocks merge — no overrides without the user's explicit instruction.

## 9. On-Device Smoke Test (Patrol)

Every release candidate APK passes the standing Patrol suite (§ 11.2) on every enrolled device before install/deploy (release checklist refs this):

```bash
scripts/smoke_device.sh <adb-serial>            # whole suite + logcat crash scan
scripts/smoke_device.sh <serial> integration_test/smoke_solo_match_test.dart
```

- **Text anchors** ( Patrol selectors AND wrapper assertions — label change ⇒ suite + this list change in the same commit): `PLAY SOLO`, `PLAY FRIENDS`, `Coming soon`, `First to the finish line`, `JUMP`, `Quit the race?`, `KEEP RUNNING`, `QUIT`, `SKIP`, `START`, `PLAY AGAIN`, `HOME`, `Sound`, `Fredoka font`, `Nunito font`, `Phosphor Icons (Fill)`, rank ordinals (`1st`, `T-1st`).
- The suite runs on the Pi rig only (`192.168.0.5:5555`) — absolute (user directive 2026-09-19).
- Failure output includes the last fatal exceptions for triage.

## 10. Strict Test-Writing Law (unit, widget, domain, integration logic tests)

Hard rules. A test that breaks any of them does not merge — no exceptions, no waivers. Reviewers grade violations as blockers (AGENTS § 10).

**Scope carve-outs (explicit, exhaustive):**
- **§ 11 Patrol device flows** are exempt from 10.1.1 (composite-flow names are the point — `smoke_race_finish` is one user flow) and 10.1.3 (E2E steps interleave act/assert by nature). All other rules apply unchanged.
- **Grandfathered debt**: suites predating this law (some `_and_` names, `isNotNull` matchers, widget-test `pumpAndSettle` — see § 11.1 for why widget scope differs) stay as-is until touched; a file picks up full compliance the next time it is edited. New tests and new files: zero tolerance.

### 10.1 Structure & naming

1. **One behavior per test.** A test name that needs "and" to describe itself must be split. `points_scale_to_ranked_players`, not `points_and_ranks_and_ties`.
2. **Name = behavior sentence**: unit/domain/integration tests use `<subject>_<expected-behavior>[_<condition>]` in snake_case. Spec-reference tests prefix `gdd_<section>_`, network-doc tests `net_<section>_`, ux-checklist `ux_<section>_`. **Widget tests use prose sentences with spaces** (widget-test corpus convention; `testWidgets('shows the typographic logo')`) — snake_case is not required there.
3. **AAA layout**: Arrange, Act, Assert — separated by blank lines or comments. An assert before the final act block is a structural defect.
4. **File per subject**: test files mirror the unit under test (`placements.dart` → `placements_test.dart`). Cross-subject suites need a documented reason in the file header.

### 10.2 Determinism & isolation

5. **Zero wall-clock.** No `Future.delayed`, `sleep`, `DateTime.now` in test bodies. Time is injected (clock/stepper/manual ticker). A test that passes "after a while" is banned.
6. **Zero shared mutable state.** Every test builds its own fixture; no test-order dependence, no static caches mutated by tests. Running any single file alone must pass.
7. **Randomness only seeded.** Every `Random` in a test carries an explicit seed; a flaky-by-randomness test is a blocker.
8. **No I/O in unit tests.** File, socket, platform channel, prefs — fake the boundary (`KeyValueStorage`, `FakeConnection` precedents). Real I/O belongs to integration tests only.
9. **No network.** Loopback in-process sockets are integration scope; anything else is forbidden.

### 10.3 Assertions

10. **Assert the behavior, exactly once logically.** Multiple expects are fine when they verify facets of ONE outcome; asserting two different behaviors belongs in two tests.
11. **Precise matchers.** No `isNotNull` where `equals(x)` is possible; no `greaterThan(0)` where the exact value is specified. Doubles: `closeTo` with an epsilon that has a stated reason (comment).
12. **Failure messages must be self-explanatory**: every `expect` on a loop or with non-obvious subject carries a `reason:`.
13. **Expected values are literals with meaning** — expected `4` points is fine inline; expected computed values (`x + 1`) that mirror the implementation under test are forbidden (tautology smell).
14. **Exceptions**: assert type AND payload fields (`having(...)`), not just `throws`.

### 10.4 Coverage & cases

15. **Boundary + failure mandatory.** Every rule-level behavior ships: the normal case, each boundary (0, 1, N, max, exactly-at-threshold), and at least one failure path (invalid input, missing data, wrong state). A suite with only happy paths is incomplete — reviewers reject.
16. **Every spec edge case has a named test** (GDD § 7, network doc § 5/§ 8, ux-checklist rows). The doc table and the test list are cross-checked in review.
17. **Domain tests need no mocks** (existing rule § 6) — needing one is a design alarm raised to the architect (main thread), not silently worked around.
18. **Regression law**: every bug fix adds a test that fails on the pre-fix code. The fix PR contains both.

### 10.5 Hygiene

19. **Tests are code**: same lint gates (`dart analyze` zero), same 80-col, same language. Test files are NOT exempt from style.
20. **No `skip:` without a linked issue note in the same line**; skipped tests are tracked, not forgotten.
21. **No test-only production code.** `@visibleForTesting` exposure is allowed; behavior existing only so a test can reach it is forbidden.
22. **Deleting a test requires a reason in the commit body** — replaced-by-X, spec-changed (with doc diff), or duplicate.

## 11. Patrol (device E2E)

Patrol runs the app on real devices and drives the real Flutter widget tree — it sees what uiautomator cannot (LineageOS Pi precedent). It is the ONLY sanctioned device-UI automation layer; raw adb UI scripting is a thin launcher wrapper at most.

### 11.1 Position & rules

- Location: `app/integration_test/*.dart`, naming `smoke_<flow>_test.dart` / `e2e_<flow>_test.dart` — the `_test.dart` suffix is a hard `patrol_cli` requirement (it rejects other targets). One flow per file, ≤ 300 lines.
- Pyramid top: Patrol suites are regression gates for user-visible flows. They never replace unit/widget/domain tests; asserting game RULES here (points math etc.) is a layer violation — rules are domain-test territory. Patrol asserts **what is on screen**.
- Selectors: public text anchors (§ 9 list — same list, same commit when labels change) first; `Key` finds for dynamic content. Never index-based (`texts[2]`) or coordinate taps.
- Waiting: `patrolTester.waitUntilVisible/...` only. `Future.delayed`/sleeps are banned (Law § 10.2.5 applies here too). **`pumpAndSettle` is banned in all device/Patrol tests** — ambient loops (backdrop drift, pulses) schedule frames forever on a real device; the app never settles. (Widget tests under fake-async are unaffected — their `pumpAndSettle` terminates.) Time-sensitive taps use `settlePolicy: SettlePolicy.noSettle` + explicit `waitUntilVisible` (intro countdown precedent).
- Native interactions: `native.pressBack()` for system back; no raw `adb shell input` inside Patrol tests.
- Determinism: the match seed is wall-clock in the shell (not injectable today — backlog: seeded test config). Race-finish therefore asserts that placements RENDER (incl. `T-1st` shared-rank, GDD § 7.6), never the outcome; screenshots may be captured but never asserted pixel-by-pixel (token colors vary by theme drift).
- Every new user-visible flow adds its Patrol case in the same PR (DoD link, `docs/05` § 6).
- Runs: `patrol test --device 192.168.0.5:5555` (or `scripts/smoke_device.sh` which enforces the rig) — **Pi rig ONLY, absolute (user directive 2026-09-19; phone = manual-install target, never a test device)**. Pi pass = release checklist condition. CI emulator hosting is backlog.

### 11.2 Required cases (minimum standing suite)

| # | Case (`smoke_*_test.dart`) | Steps | Hard asserts |
|---|----------------------|-------|--------------|
| 1 | `smoke_first_launch` | cold start, first-launch | onboarding shows; SKIP tap lands on Home (`PLAY SOLO` visible) |
| 2 | `smoke_solo_match` | Home → PLAY SOLO | intro shows rule line; countdown ends in play (`JUMP` visible); 3 jumps complete without exception |
| 3 | `smoke_quit_dialog` | in play → `native.pressBack()` | dialog `Quit the race?` shows; KEEP RUNNING returns to play (`JUMP` visible) |
| 4 | `smoke_quit_to_home` | in play → back → QUIT | Home visible (`PLAY SOLO`); app process alive |
| 5 | `smoke_race_finish` | play to completion (round cap 90 s) | results screen shows placements (outcome not asserted — wall-clock seed, see § 11.1); PLAY AGAIN restarts intro |
| 6 | `smoke_profile_flow` | Home → profile avatar | profile editor opens (field visible); back returns Home. Persistence/swatch behavior is widget-test territory |
| 7 | `smoke_settings_flow` | Home → gear | settings opens; sound toggle flips; credits lists every ATTRIBUTION row; back returns |
| 8 | `smoke_orientation_lock` | portrait steady-state (platform note: patrol 3.20 has no rotate API and the Pi rig has no accelerometer — true rotation coverage is backlog) | UI renders unchanged after settle |

Standing suite must stay green on every enrolled device; a red case blocks release exactly like CI.
