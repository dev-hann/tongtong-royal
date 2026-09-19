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

## 9. On-Device Smoke Test

Every release candidate APK passes the device smoke before install/deploy (release checklist refs this):

```bash
scripts/smoke_device.sh <adb-serial>   # USB or network adb device
```

Flow asserted: install → launch → (onboarding SKIP if first launch) → home renders → PLAY SOLO → intro countdown → play (JUMP present, tapped ×3) → system back → quit dialog → KEEP RUNNING resumes → back → QUIT → home → process alive → **zero FATAL EXCEPTIONS** in logcat.

- Text anchors come from real widget strings (`PLAY SOLO`, `First to the finish line`, `JUMP`, `Quit the race`, `KEEP RUNNING`, `QUIT`, `SKIP`) — if a label changes, the script and this list change in the same commit.
- The smoke runs on every connected test device (phone today; the LineageOS Pi rig when enrolled).
- Failure output includes the last fatal exceptions for triage.
