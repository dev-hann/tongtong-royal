# 05 — Conventions

---

## 1. Static Analysis (mechanically enforced)

- Every package uses `package:very_good_analysis` with the strictest practical settings; `analysis_options.yaml` extends it.
- **CI and local gate: zero warnings, zero infos, zero errors.** `-` ignores require a written justification comment and are review-blockers by default.
- Line length: 80.

## 2. Code Organization

| Limit | Value |
|-------|-------|
| File length | ≤ 300 lines (test fixtures exempt) |
| Function length | ≤ 40 lines |
| Constructor parameters | Prefer named; > 6 params → introduce a params object |

Naming: Dart style (`lowerCamelCase`, `UpperCamelCase`, `snake_case.dart`). Domain types use game vocabulary from the GDD (`RoundResult`, `Placement`) — one concept, one name, everywhere.

**Design tokens (mandatory)**: all colors, text styles, spacing, radii, and motion durations come from `app/lib/design/tokens.dart`. Inline `Color(0x...)`, raw `TextStyle(...)` in screens, and ad-hoc paddings outside the token scale are review-blockers. Shared UI building blocks live in `app/lib/design/widgets/`; the in-game HUD (incl. the one-button action control) lives in `app/lib/design/game_hud/`.

## 3. Error Handling & Logging

- **No empty catch.** No swallowed futures (`unawaited` is acceptable only with a comment explaining why the result is irrelevant).
- Errors: handle at the layer that can act on them; everything else propagates (domain throws typed exceptions; UI shows messages; infra logs + retries/reconnects).
- Logging: the standard logger package per package (no `print`, ever — CI greps for it).
- Logs carry context: `playerId`, `roomId`, `tick` where relevant.

## 4. Git Workflow

- Branch from `main`: `feat/<scope>-<summary>`, `fix/<scope>-<summary>`, `docs/<summary>`, `test/<summary>`, `chore/<summary>`.
- **Conventional Commits**: `feat(server): enforce 4KB message cap`, `fix(game): clamp dash velocity to maxLinearVelocity`, `docs: add race timeout rule to GDD § 7.4`.
- **One commit = one concern.** Tests and their implementation ship together. Doc updates caused by a change ship in the same commit.
- Commit body explains *why* for anything non-obvious.
- PRs: CI green is merge-blocking. Solo development still uses PRs for anything touching `shared/` or docs (self-review catches drift).

### Commit granularity example

```
BAD:  feat: add race minigame + fix joystick + update docs + tweak colors
GOOD: feat(game): checkpoint respawn on fall (GDD § 4.1)
      test(domain): rank unfinished racers by distance on timeout (GDD § 7.4)
      docs: clarify survivor timeout ranks share best rank (GDD § 7.5)
```

## 5. Versioning

- Repo/app: SemVer `MAJOR.MINOR.PATCH+build`. Milestones target `0.x`: M1 → `0.1.0`, M3 → `0.3.0`, store release → `1.0.0`.
- **Protocol version** (`shared/protocol.protocolVersion`): independent integer, bumped on any breaking message change; server supports N and N-1 (architecture doc § 7).
- Dependency bumps: isolated commits, never mixed with features.

## 6. Definition of Done

### Universal (every commit)

- [ ] Failing test written first (AGENTS § 4 cycle followed)
- [ ] `dart analyze` / `flutter analyze` clean
- [ ] All tests green locally
- [ ] Layer anti-pattern sections consulted; no violations introduced
- [ ] Docs updated in-commit if behavior/rules changed
- [ ] No secrets, no `print`, no empty catch, no magic numbers
- [ ] **Deployable builds additionally pass the compliance review (AGENTS § 10): zero blockers**

### M1 — Single-player core

- [ ] Character: move/jump/dash against physics standards (CCD, clamps)
- [ ] One Trap Race course completable start → finish
- [ ] Checkpoint respawn + fall zones covered by headless physics tests
- [ ] Tuning constants all in `shared/physics`
- [ ] GDD § 4.1 behaviors tested (finish detection, timeout ranking by distance)

### M2 — Shell UI

- [ ] Full state machine: home → intro → play → results (terminal) → home
- [ ] Widget tests per screen; state transitions unit-tested in domain
- [ ] No game logic in widgets (architecture § 10 audit)

### M3 — Server + netcode

- [ ] Rooms/invite codes: lifecycle per network doc § 8, all tested
- [ ] Handshake + version gate; malformed-message rejection suite
- [ ] 30/20 Hz channels; interpolation with 100 ms buffer
- [ ] Disconnect policies (§ 5) incl. backgrounding auto-rejoin, all tested
- [ ] E2E integration test green (testing doc § 7)

### M4 — Minigame expansion *(superseded 2026-09-19)*

Originally "Hammer Dodge + King of the Hill + selection rule". Superseded twice: first by the single-game scope reset, then by **GDD v2 (show era)**. The active game work is defined by `docs/games/*.md` specs — current: Hammer Dodge revival (R2) + Trap Race FINAL variant. DoD: every game doc section implemented + tested; show structure (4→3→2→1) green in domain; crown stats recorded; PATROL anchors per game doc present on the Pi rig.

### M5 — Release

- [ ] `docs/06-release-legal.md` checklist complete (GRAC, privacy, attribution)
- [ ] Crash reporting live; performance budgets met on min-spec device
- [ ] Ads integrated behind config flag; store builds submitted

## 7. Backlog Discipline

The GDD § 8.2 backlog is out of scope until the user moves it into a milestone. Do not "prepare" for backlog items with speculative abstractions (YAGNI is law).
