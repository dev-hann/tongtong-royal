# TongTong Royal (통통로얄)

A 2-4 player real-time physics minigame collection for mobile. Think "pocket Fall Guys with friends": join a room with an invite code, play 5 short rounds of physics minigames, accumulate points, and claim the podium.

## Stack

| Layer | Technology |
|-------|------------|
| Client game | Flutter + [Flame](https://flame-engine.org) + Forge2D (Box2D port) |
| Client UI shell | Flutter widgets (menus, lobby, results) |
| Server | Pure Dart, `shelf` + WebSockets (relay only, no simulation) |
| Shared code | Pure Dart package (domain rules, protocol models, physics constants) |
| Deploy | Server: Fly.io free tier. Client: Google Play / App Store |

## Monorepo Layout

```
tongtong-royal/
├── app/        # Flutter client (Flame + Forge2D + UI shell)
├── server/     # Dart WebSocket relay server (rooms, invite codes)
├── shared/     # Pure Dart: domain rules, protocol models, physics constants
├── docs/       # Project bible (read order below)
└── .github/    # CI
```

`shared` is the contract: both `app` and `server` depend on it; it depends on nothing platform-specific. Layer boundaries are enforced physically by package structure (see `docs/02-architecture.md`).

## Documentation (the Bible)

Read in this order. These documents are the project's code of conduct; they supersede memory, habit, and guesswork.

| Priority | Document | Content |
|----------|----------|---------|
| 1 | [`AGENTS.md`](AGENTS.md) | Working rules for AI/human contributors. TDD cycle, prohibitions, gates |
| 2 | [`docs/01-game-design.md`](docs/01-game-design.md) | Game rules, minigame specs, game-rule edge cases |
| 3 | [`docs/02-architecture.md`](docs/02-architecture.md) | Layers, ownership, physics standards, layer anti-patterns |
| 4 | [`docs/03-testing-strategy.md`](docs/03-testing-strategy.md) | Test pyramid, coverage gates, test smells |
| 5 | [`docs/04-network-edge-cases.md`](docs/04-network-edge-cases.md) | Netcode edge cases, adversarial input, netcode anti-patterns |
| 6 | [`docs/05-conventions.md`](docs/05-conventions.md) | Code style, Git workflow, versioning, Definition of Done |
| 7 | [`docs/06-release-legal.md`](docs/06-release-legal.md) | Store rating, privacy, asset licensing |
| 8 | [`docs/07-design-guide.md`](docs/07-design-guide.md) | Visual language: typography, color usage, motion/juice, screen patterns |
| 9 | [`docs/08-roadmap.md`](docs/08-roadmap.md) | Post-launch candidates with start triggers, non-goals |

**Conflict resolution order: `AGENTS.md` > `docs/*` > `README.md`.** If two documents disagree, the higher-priority one wins, and you must fix the lower one in the same commit.

## Development Workflow

Strict TDD. Every behavior change starts with a failing test. Full rules: `AGENTS.md` and `docs/03-testing-strategy.md`.

```bash
# From repo root (pub workspaces)
dart pub get

# Gates — must pass before any commit
dart analyze
dart test
```

CI (`.github/workflows/ci.yml`) runs the same gates on every push and pull request. A red CI blocks merge, no exceptions.

## Roadmap

| Milestone | Scope | Est. |
|-----------|-------|------|
| M1 | Single-player core: physics character (move/jump/dash), one race course | 2-3 wk |
| M2 | Shell UI: lobby → intro → play → results → podium state machine | 1-2 wk |
| M3 | Server + netcode: rooms/invite codes, 20Hz snapshots, interpolation | 3-4 wk |
| M4 | Two more minigames (Hammer Dodge, King of the Hill) | 3-4 wk |
| M5 | Polish: disconnect handling, sound, ads, store release | 2-3 wk |

Milestone acceptance criteria: `docs/05-conventions.md` § Definition of Done.
