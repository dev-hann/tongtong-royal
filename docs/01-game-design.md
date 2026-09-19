# 01 — Game Design Document (GDD)

TongTong Royal: 2-4 player real-time physics minigame collection. Fall Guys-scale fun, pocket-scale scope.

---

## 1. Core Loop

```
Home → ROUND_INTRO (3s, rule one-liner)
     → ROUND_PLAY (one Trap Race, ≤90s)
     → ROUND_RESULTS (terminal: placements)
        ├─ PLAY AGAIN → ROUND_INTRO (fresh mapSeed)
        └─ HOME → Home
```

## 2. Round Structure & Scoring

- **A match = ONE round** (single-shot flow, MVP simplification 2026-09-19). The race's finishing order IS the final ranking.
- Ranking = placement in the round. **No cumulative points, no multi-round tie-breaks.** Placement points exist only for stats/HUD display:

| Players in round | 1st | 2nd | 3rd | 4th |
|------------------|-----|-----|-----|-----|
| 4 | 4 | 3 | 2 | 1 |
| 3 | 3 | 2 | 1 | — |
| 2 | 2 | 1 | — | — |

- **Shared ranks** (e.g. same-tick finish, § 7.6): players share the rank; the next rank is skipped. A shared 1st means two winners.

## 3. Controls (one button, fully automatic movement)

One-button with automatic movement (hyper-casual standard):

| Minigame | Button | Automatic behavior |
|----------|--------|--------------------|
| Trap Race | Jump | Auto-run: constant rightward movement |

Rules:

- **One button.** No joystick, no d-pad, no second button.
- Movement is **fully automatic** — the player only times the jump.
- Internal representation: clients translate (auto-steering + button edges) into the `PlayerInputState` vector. Protocol, server, netcode, and bots are unaffected.
- Bot opponents (§ 9) are unaffected: they already produce input vectors directly.
- The dash verb remains in the input vocabulary (`GameVerb.dash`) for future minigames; no MVP game uses it.

## 4. MVP Minigame

One minigame (one archetype, the race; more are planned post-MVP § 8.2 / roadmap 08). Maps are data. The minigame implements the shared `MiniGame` interface (see `docs/02-architecture.md` § Minigame Interface).

### 4.1 Trap Race (archetype: race)

- **Goal**: first to the finish line. Placement = finish order.
- **Course**: static platforms, rotating hammers (kinematic bodies), moving platforms, fall zones (kill volumes → respawn at last checkpoint).
- **Checkpoints**: crossing a checkpoint sets respawn point. Respawn keeps you in the race (no elimination).
- **Round end**: when all players finish, or timeout (90s) — see §7.4.

## 5. Round Flow States

```
LOBBY(Home) → ROUND_INTRO (3s, rule one-liner)
            → ROUND_PLAY (≤90s)
            → ROUND_RESULTS (placements, no auto-advance)
            → LOBBY(Home)      [PLAY AGAIN re-enters ROUND_INTRO with a fresh seed]

ROUND_PLAY → LOBBY(Home)  [ABANDON: solo quit mid-round — § 7.11]
```

State machine is owned by `shared/domain`. With the single-round match, `ROUND_RESULTS → LOBBY` is the ending transition (`toPodium` remains available to the machine for compatibility but the MVP shell does not route through PODIUM).

## 6. Round Seeding

Each play generates a fresh `mapSeed` (host/solo side); identical seed = identical course variant for every participant (network doc § Sequencing). No selection rule — there is one minigame.

## 7. Game-Rule Edge Cases (exhaustive — do not improvise beyond this list)

### 7.1 Start conditions

- Round 1 starts only when **all present players are ready** AND the **host presses Start**.
- Minimum 2 players to start a match. Below that, the room stays in lobby.

### 7.2 Player leaves mid-round (online rooms; infra preserved)

- The round **continues** with remaining players; ranking scales to players ranked at round end (table §2).
- The leaver is **excluded from the results ranking** (forfeit).
- Their physics body stays in the world, idle (no input), for the rest of the round. See network doc § Player Disconnect.

### 7.3 One player remains (everyone else left)

- The round **ends immediately**. The remaining player **wins**.

### 7.4 Race: nobody finishes by timeout

- At timeout, unfinished players are ranked by **forward progress distance** (furthest first), below all finishers.

### 7.6 Simultaneous finish (same tick)

- Players finishing on the same simulation tick **share the rank**; the next rank is skipped (two players share 1st → next finisher is 3rd).

### 7.8 AFK players

- **MVP: no AFK detection or handling.** Explicitly out of scope (backlog). Do not implement idle kicks or auto-ready.

### 7.9 Rejoining mid-round (online rooms)

- A leaver may rejoin within the reconnect grace window (network doc § Reconnect); they resume as an idle-body seat for the rest of the round and re-enter play on the next round start. They cannot rejoin after the results screen.

### 7.10 Host starts a round, then a player readies/unreadies

- Once `ROUND_INTRO` begins, ready state is frozen. Late/absent players are spectators until the next round.

### 7.11 Solo abandon (quit mid-round)

- Solo (vs bots) only: the local player may quit during `ROUND_PLAY` — an exit button top-right or the system back gesture, both behind a confirm dialog ("Quit the race?").
- Transition: `ROUND_PLAY → LOBBY` directly (machine `abandon`). No `ROUND_RESULTS`, **no result recorded, no stats recorded** (abandoned races never reach the results screen, which is the single stats trigger).
- The bots' virtual outcome is discarded; starting solo again begins a fresh match with a fresh seed.

## 8. Scope

### 8.1 MVP (in)

- **Single-round solo play vs bots** (1 human + 3 bots): Home → intro → one Trap Race → results → Home. This is the MVP release flow.
- **Multiplayer infra preserved but not user-facing yet**: rooms/invite codes/netcode remain in the repo (server, protocol, host/remote client code) for the planned rebuild — do not delete, do not wire into the shell.
- **Bot fill** (§ 9).
- **Local profile** (no accounts, no server sync): nickname (first-launch onboarding, default `PLAYER`, editable), player color (persisted; drives seat color + in-game local rendering), stats (races played, wins, first-place finishes — recorded at the results screen, stored locally only).
- **Settings**: sound toggle (audio engine lands with M5; the flag persists now), credits (asset attribution view — legal § 3 duty), app version.
- Sound effects, best-score persistence (local), simple character customization (color).

### 8.2 Backlog (explicitly out — do not build)

- Random matchmaking, AFK handling, spectator mode, cosmetics beyond color, chat, seasons, ranked, bot difficulty tiers.
- Achievements/quests, progression/rewards, levels, replay history.
- **Hammer Dodge** and **King of the Hill** — removed from MVP (2026-09-19 scope reset to single-game single-round; gameplay internals to be re-approached post-reset). The race engine remains the archetype base.

## 9. Bot Players

### 9.1 Fill policy

- Solo play fills to 4 seats with bots (never displacing humans).
- A bot's identity: `playerId` = `bot-1`..`bot-3`, nickname = `BOT 1`..`BOT 3`.
- Bots are auto-ready; they never block start conditions.
- Bots participate fully: placements, results — identical to humans, marked via nickname.
- Disconnect rules do not apply to bots.
- Bots run **host-side**: the simulating client generates their inputs each tick. Nothing bot-related crosses the wire.

### 9.2 Behavior (difficulty: basic)

- Heuristic steering. No pathfinding, no learning — predictable, fair-ish, occasionally clumsy (beatable by an average human).
- Common: bots act on their own pose + map data + tick only (no omniscience; contact-level awareness of nearby bodies is allowed).
- Race: run toward the finish, jump when obstructed or at gaps (map-data driven), occasional dash.
