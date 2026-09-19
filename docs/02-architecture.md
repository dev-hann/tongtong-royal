# 02 — Architecture

---

## 1. Monorepo & Dependency Graph

```
┌─────────────┐      ┌─────────────┐
│    app/     │      │   server/   │
│   Flutter   │      │ Pure Dart   │
│ Flame+Forge │      │ shelf + WS  │
└──────┬──────┘      └──────┬──────┘
       │       ┌────────────┘
       ▼       ▼
   ┌───────────────┐
   │    shared/    │   PURE DART — no Flutter, no Flame, no I/O
   │  domain/      │   game rules, round state machine, scoring, judging
   │  protocol/    │   typed WS message models + (de)serialization
   │  physics/     │   gameplay tuning constants + pure validation fns
   └───────────────┘
```

**Rules:**

1. Dependency arrows are **one-way and only point downward**: `app → shared`, `server → shared`. `app` and `server` never reference each other.
2. Layer separation is **physically enforced by package boundaries**. `shared/` declares no Flutter/Flame dependencies, so importing them there is a compile error, not a convention. Never weaken this with `dependency_overrides` or dynamic imports.
3. **Forge2D lives only in `app/game/`.** The server never simulates physics (it is a relay). Host-authoritative simulation runs on the host *client*.
4. `shared/` is the contract. Any message format, rule, or constant used by both sides must live there.

## 2. Ownership Matrix (who is allowed to know what)

| Concern | Owner | Everyone else |
|---------|-------|---------------|
| Round state machine, scoring, tie-breaks, placement rules | `shared/domain` | Call it, never re-implement |
| Win/finish/elimination judging | `shared/domain` (pure functions over simulation events) | Emit events, don't judge |
| Physics simulation | `app/game` (host client only) | Render snapshots, don't simulate |
| Rendering, animation, cameras | `app/game` + `app/presentation` | No rules knowledge |
| Room lifecycle, invite codes, relay, validation | `server` | — |
| Message format | `shared/protocol` | Only typed models, no hand-rolled JSON |
| Gameplay tuning numbers | `shared/physics` (constants) | No magic numbers anywhere else |
| Bot players (fill opponents) | `app/game/bots` + host/solo runtimes (host-side input sources, GDD § 9) | Server knows nothing about bots — they are ordinary snapshot entries |

**Judging rule (critical):** Flame components, widgets, and server code must never compute points, placements, or winners. They feed raw events (`PlayerFinished(tick, playerId)`) into domain functions and display/relay the result.

## 3. Minigame Interface (v2 — qualification era)

Every minigame implements the domain-level interface (defined in `shared/domain`). Since GDD v2, rounds produce **qualification verdicts**, not placement scores:

```dart
abstract class MiniGame {
  MiniGameId get id;
  // Domain-side: given ordered events for one round, decide who
  // QUALIFIES (GDD 2/7.1) — not who scores.
  QualificationResult resolve(RoundEvents events); // events carry roundIndex
  MiniGameSpec get spec; // names, verb, rule one-liner, timeout
}

/// Per-round verdict: qualifiers (+ shared-qualification groups per
/// GDD 7.1), eliminated, and champion when this round is the FINAL.
final class QualificationResult {
  final List<PlayerId> qualified;   // order matters within (finish order)
  final List<PlayerId> eliminated;  // elimination order
  final bool isFinal;               // FINAL rounds crown a champion
  final PlayerId? champion;         // null unless isFinal; shared-crown
                                    // (GDD 7.2) yields BOTH in qualified
                                    // with champion recorded per rules
}
```

The quota is a property of the SHOW SCHEDULE (GDD § 4), not the game: resolvers receive the quota via the event/input channel and apply it. The show state machine chains rounds `4 → 3 → 2 → crown` (domain-owned; `QUALIFY_FLASH` replaces the v1 `ROUND_RESULTS` phase; `toPodium` is the reachable ending).

**Event channels (concrete):** `RoundEvents` carries ordered discrete events (`PlayerFinished`, `PlayerFell`, `PlayerEliminated`, ... — sealed set) + quota + roster. Continuous data (e.g. race progress samples) travels via an optional per-minigame input parameter (e.g. `TrapRaceInput { roster, progressSamples }`). Last progress sample per player wins.

- Rules live in `shared/domain` (qualification from events). Show schedule (which game at which slot, quotas) is also domain: a `ShowSchedule` value object, not shell logic.
- Physics construction (bodies, obstacles, map layout) lives in `app/game`, driven by **map data (JSON)** per `docs/games/*.md` schema + `mapSeed = f(showSeed, roundIndex)`.
- The host runtime is minigame-agnostic: it drives any arena/course simulation through the `RoundSimulation` seam (`app/game/round_simulation.dart`) and dispatches per-minigame glue in `app/net/host/` (simulation factory + resolve-input packing).
- Adding a variant of an existing archetype = new map data + renderer + a game-doc spec (`docs/games/*.md`). A new archetype additionally adds one case to each glue switch (`defaultRoundSimulationFactory`, `resolveRound`) — and a new doc from `_template.md`.

## 4. Host-Authoritative Netcode (summary)

Only the host client simulates. Server relays. Details, rates, and edge cases: `docs/04-network-edge-cases.md`.

```
Client A (HOST)   Server (relay)   Client B/C/D
   │ simulate         │                │
   │◄──── inputs ─────│◄─── inputs ────│  (30 Hz each)
   │                  │                │
   ├── snapshots ────►├─── snapshots ─►│  (20 Hz, host tick)
   │                  │                │ interpolate render
   │── round events/states ───────────►│  (state machine transitions)
```

- **Global tick**: host increments a single integer tick; snapshots reference it.
- **Determinism**: fixed timestep (`shared/physics.tickRate`). Only the host simulates, so cross-platform float determinism is *not required* — clients render snapshots. Do not introduce client-side simulation of remote players.
- **Round timer**: owned by the host. Client UIs render host-provided time, never local timers.

## 5. Physics Standards (mandatory — from `docs` review, treat as law)

| Rule | Specification |
|------|---------------|
| Fixed timestep | Simulation steps at a fixed dt from `shared/physics`. No wall-clock physics. |
| Tunneling prevention | Player bodies use `bullet: true` (CCD). Walls have a minimum thickness from `shared/physics.minWallThickness`. Dash applies an impulse **capped** by `maxSpeed` clamp. |
| Velocity clamp | Every tick, host clamps all player linear/angular velocities to `maxLinearVelocity`/`maxAngularVelocity`. |
| NaN/explosion guard | Every tick, host checks positions/velocities for NaN or values beyond `worldBounds`; violator is respawned at last checkpoint (and logged). Explosion respawn emits **no domain event** (unlike fall-zone `PlayerFell`) — it is silent recovery. |
| Stuck detection | Host-side: player with active input and near-zero displacement for `stuckThresholdSeconds` (5s) is respawned at last checkpoint. |
| Contact parameters | Friction/restitution values for player/ground/player-player are constants in `shared/physics`. No inline tuning. |
| Kill volumes | Fall zones are sensor bodies; host emits `PlayerFell` events; domain decides respawn (map data defines checkpoint). |

## 6. Client Layering (`app/`)

```
app/
├── design/        # Design system: tokens, theme, shared widgets, game HUD
├── game/          # Flame+Forge2D: components, bodies, cameras, effects
├── presentation/  # Flutter widgets: menus, lobby, HUD, results, podium
└── infra/         # WS client, lifecycle handling, prefs, ads
```

- `presentation` renders state from domain/view models; contains no game rules.
- `game` renders the simulated world and forwards raw input/events; contains no rules.
- `infra` moves bytes; contains no rules, no UI.
- `design` holds **all visual tokens** (colors, typography, spacing, radii, motion) and shared UI components (screen widgets' building blocks + in-game HUD incl. the action button). Both `presentation` and `game/view` consume it; it depends on nothing app-specific. **Rule: no inline `Color(0x...)`, no hand-rolled text styles outside `design/`** — tokens only. Game renderers (painters) take player/arena colors from `design` tokens.
- Both `presentation` and `game` may depend on `shared/domain` and `shared/physics`. Neither depends on the other for logic; overlays communicate through explicit state objects.

## 7. Protocol Versioning

- `shared/protocol` carries a `protocolVersion` integer. Breaking message changes bump it.
- Server supports **current and one previous** protocol version (N and N-1). Older clients receive a `VersionMismatch` message and a store-update prompt.
- The handshake (first message) declares the version; mismatched non-supported versions are rejected before joining a room (network doc § Handshake).

## 8. Anti-Patterns — Domain (`shared/domain`)

**BAD — rule logic leaking outside domain:**
```dart
// In a Flame component:
if (finishedPlayers.length == totalPlayers) awardPoints(); // ❌ judging in renderer
```
**GOOD:**
```dart
final result = miniGame.resolve(roundEvents); // domain judges
hud.showResults(result.placements);           // renderer displays
```

**BAD — I/O in domain:**
```dart
Future<int> loadPointsFor(String playerId) async {
  final prefs = await SharedPreferences.getInstance(); // ❌ no I/O in domain
```
**GOOD:** infra loads raw data, domain receives plain values: `Points.forPlacements([3, 1, 2, 4])`.

**BAD — duplicating a rule:** re-implementing the tie-break in the podium widget. **GOOD:** call `Rankings.finalRanking(roundResults)`.

## 9. Anti-Patterns — Game Layer (`app/game`, Flame/Forge2D)

**BAD — magic numbers:**
```dart
body.applyLinearImpulse(Vector2(0, 42.5)); // ❌ what is 42.5?
```
**GOOD:** `body.applyLinearImpulse(Vector2(0, PhysicsConsts.jumpImpulse));`

**BAD — accumulating state in components:** storing points/round history on a `PlayerComponent`. Components are render/simulation objects; state belongs to domain models.

**BAD — client-side simulation of remote players** (predicting other players' physics). Only local-player prediction is allowed; everyone else is interpolated snapshots.

**BAD — skipping clamps "just for now":** every body created outside the standards table (§5) is a defect.

## 10. Anti-Patterns — Presentation (`app/presentation`)

**BAD — logic in `build()`:**
```dart
Widget build(context) {
  final winner = players.reduce((a, b) => a.points > b.points ? a : b); // ❌
```
**GOOD:** view models computed from domain (`Rankings.finalRanking(...)`) before build; widgets arrange pixels.

**BAD — widgets reaching into `infra` directly** (opening sockets from a button handler). **GOOD:** route through the app-level controller/state object.

---

Living spec. Implementation changed something? Update this file in the same commit (see `AGENTS.md` § 7).
