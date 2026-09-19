# AGENTS.md — Working Rules for TongTong Royal

This file is the **code of conduct** for every contributor, human or AI. It has the highest authority in this repository (order: `AGENTS.md` > `docs/*` > `README.md`). If any instruction in this file conflicts with a request or habit, this file wins — unless the user explicitly overrides it in the current session.

---

## 1. Project Identity

TongTong Royal is a single-round one-button physics race vs bots (multiplayer infra preserved for a future rebuild). Full rules: `docs/01-game-design.md`.

## 2. Language Rules

- **Documents**: English.
- **Code identifiers, comments, commit messages, PR titles**: English.
- Conversation with the user may be Korean; everything committed to the repo is English.

## 3. Pinned Environment

| Tool | Version |
|------|---------|
| Dart SDK | `>=3.5.0` (workspace feature required: 3.6+) |
| Flutter | Stable channel, `>=3.24.0` |
| Package management | Pub workspaces (single `dart pub get` at repo root) |

Never upgrade major dependencies mid-milestone. Dependency bumps are their own commit with their own test run.

**Patrol (device E2E, docs/03 § 11)**: `patrol_cli` **3.11.0** (global: `dart pub global activate patrol_cli 3.11.0`) pairs with `patrol` dart package **3.20.0** (exact pin in `app/pubspec.yaml` — see the compatibility table before changing either). Run: `export PATH="$PATH:$HOME/.pub-cache/bin"` then `patrol test --device <serial> --target integration_test/<file>_test.dart` — **always from `app/`** (a repo-root run generates a root `test_bundle.dart` that trips `dart analyze`). `test_bundle.dart` is generated — never commit it.

**Known SDK quirk (this machine)**: hand-installed Flutter SDK caches ship engine artifacts without execute permission — release builds fail with "lacked sufficient permissions to execute" on `gen_snapshot` / `font-subset`. Fix: `chmod +x ~/development/flutter/bin/cache/artifacts/engine/*/linux-x64/{gen_snapshot,font-subset}`. Re-run after SDK updates.

## 4. Strict TDD — Mandatory Cycle

Every change to production code follows **Red → Green → Refactor**:

1. **Red**: Write a failing test that expresses the desired behavior. **Run it and observe the failure.** Confirm it fails for the *right reason* (assertion failure / expected exception), not a compile error in unrelated code or a typo.
2. **Green**: Write the *minimum* code that makes the test pass.
3. **Refactor**: Clean up with tests staying green. Skipping this phase is forbidden.

### 4.1 TDD Scope — Exhaustive

Strict test-first applies to:

- All of `shared/` (domain rules, protocol models, physics constants).
- Game logic in `app/` (round state machine wiring, controller logic, minigame behaviors).
- All of `server/` (room lifecycle, relay, validation).

**Explicit exemptions** (no failing test required first):

- `main.dart` / entry points and bootstrap wiring.
- Generated code.
- Pure configuration: `analysis_options.yaml`, CI YAML, manifest data.
- Visual-only tweaks where behavior is undefined by spec (e.g. colors, spacing). If in doubt, it is not visual-only.

The exemption list is closed. Do not invent new exemptions. If you believe an exemption is needed, stop and ask the user.

### 4.2 Enforcement

- CI cannot verify test-first *order*; the procedure above is mandatory on your honor and visible in your workflow (you must actually run the failing test before implementing).
- A commit that adds behavior must contain its tests in the **same commit**.
- Bug fixes start with a **reproducing test** that fails, then the fix.

## 5. Per-Task Workflow (mandatory order)

1. **Identify the layer** you will touch (domain / game / presentation / infra / server / tests).
2. **Read the anti-pattern section for that layer** before writing code:
   - `shared/domain` → `docs/02-architecture.md` § Domain Anti-Patterns
   - `app/game` (Flame/Forge2D) → `docs/02-architecture.md` § Game Layer Anti-Patterns + § Physics Standards
   - `app/presentation` → `docs/02-architecture.md` § Presentation Anti-Patterns
   - network / `app/infra` / `server` → `docs/04-network-edge-cases.md` § Netcode Anti-Patterns
   - writing tests → `docs/03-testing-strategy.md` § Test Smells
   - anything → `docs/05-conventions.md` (limits, logging, error handling)
3. Write the failing test (§4).
4. Implement minimum. Refactor.
5. Run gates: `dart analyze` (zero warnings/errors) and `dart test` (all green).
6. Update any doc section your change invalidates — **same commit**.
7. Commit: one concern per commit, Conventional Commits (`docs/05-conventions.md` § Git).

## 6. Prohibitions (hard rules)

1. **No Flutter/Flame imports in `shared/`.** The package boundary makes this a compile error; do not work around it.
2. **No reverse layer references.** Dependency arrows are one-way: `presentation → domain ← infra`, `game → domain`. Details: `docs/02-architecture.md`.
3. **No rules/judging/scoring outside `shared/domain`.** Flame components, widgets, and the server do not know game rules; they call domain code.
4. **No magic numbers** for gameplay tuning (jump force, dash impulse, tick rates). All gameplay constants live in `shared/physics` (or domain) and nowhere else.
5. **No silent failure**: empty `catch`, swallowed errors, ignored futures. Log and handle explicitly (`docs/05-conventions.md` § Error Handling).
6. **No `print`** in committed code. Use the standard logger.
7. **No client-authoritative decisions** over the network. Only the host simulates and judges (`docs/04-network-edge-cases.md`).
8. **No undefined behavior**: if a spec hole is found, do not improvise in code. Add the rule to the relevant doc first (same commit), then implement.
9. **No committing with red gates.** `dart analyze` and `dart test` must pass locally before every commit.
10. **No secrets in the repo**, including CI files and history.

## 7. Doc Sync Duty

The bible is a living spec. When implementation and docs disagree:

1. Determine which is correct (ask the user if unclear).
2. Fix the other side in the same commit.

Bible amendments go through commits that touch only docs, with `docs:` prefix, describing the rule change in the message body.

## 8. Commands

```bash
dart pub get          # at repo root (workspaces: resolves all packages)
dart analyze          # all packages
dart test             # all packages
```

Package-specific runs use `dart test` / `dart analyze` inside `app/`, `server/`, or `shared/`. Flutter-dependent code in `app/` uses `flutter test` / `flutter analyze`.

## 9. Milestone Context

Current milestone and its Definition of Done live in `docs/05-conventions.md` § Definition of Done. Do not work ahead of the current milestone without the user's instruction.

## 10. Post-Work Compliance Review (mandatory gate)

After every major wave, at milestone completion, and **always before a deployable build** (APK/store), a compliance review runs:

1. **Fresh context**: the review is performed by a subagent (or contributor) that did NOT implement the work — no implementation-context bias.
2. **Doc-based audit**: the reviewer reads the bible (`AGENTS.md`, `docs/01`–`08`) and checks the changed code against it: prohibitions (§ 6), design guide component map + token/icon rules, layer boundaries, GDD rule conformance, conventions limits (file/function size, logging), release checklist (`docs/06`).
3. **Findings are graded**: `blocker` (bible violation or spec mismatch — must be fixed before deploy), `warn` (fix or explicitly waived by the user), `note` (style/backlog candidates).
4. **Feedback loop**: any NEW class of violation found gets added to a checklist in the relevant doc (same commit as the fix) so the gate catches it next time.
5. Deploy requires: zero blockers, review report recorded in the PR/commit message.
