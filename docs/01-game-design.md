# 01 — Game Design Document (GDD) v2

TongTong Royal: a Fall Guys-benchmarked show of qualification rounds. 4 players (1 human + 3 bots in MVP), three rounds, one crown.

Game-level specs live in `docs/games/*.md` (per-game documents, `_template.md` defines the schema). This document owns SHOW-level rules only.

---

## 1. Core Loop

```
Home → SHOW [
  ROUND 1 (race)   → intro → play → qualifier flash
  ROUND 2 (survival) → intro → play → qualifier flash
  FINAL  (race variant) → intro → play → crown moment
] → Podium (crown ceremony) → Home
```

- One show = exactly **3 rounds** with player attrition `4 → 3 → 2 → 1`.
- The show runs uninterrupted — no home between rounds.
- The player's own elimination ends their view immediately (§ 7.3): summary with the simulated outcome, straight to Home or rematch.

## 2. Judgment & Rewards (Fall Guys principle)

- **Qualification is binary.** Each round has a quota; players either qualify or are eliminated. **No points, no scores, no accumulation** (the v1 placement-points system is repealed).
- The champion of the FINAL wins the **crown** — the only reward that matters.
- Profile stats (crown-centered, replacing v1 stats):
  - `crownsWon` — finals won
  - `finalsReached` — times the player reached the FINAL round
  - `showsPlayed` — shows started
- Best race time remains as a side record (finishers only, per `docs/games/trap-race.md`); it never affects show outcomes.

## 3. Controls

One button per game; each game has its own verb (auto-movement otherwise). The verb table per game lives in its game doc. MVP games are both JUMP.

## 4. The Show Structure

| Round | Game | Players | Qualification quota |
|-------|------|---------|---------------------|
| 1 | Trap Race (`docs/games/trap-race.md` § R1) | 4 | top 3 finishers/rankers |
| 2 | Hammer Dodge (`docs/games/hammer-dodge.md`) | 3 | last 2 alive |
| FINAL | Trap Race — Final variant (narrow course) | 2 | last 1 (champion) |

- Eliminated players never re-enter the show.
- If the human is eliminated, remaining rounds resolve instantly (simulation summary, § 7.3).

## 5. Round Flow States

```
LOBBY(Home) → SHOW_INTRO (3 s, round name + verb reminder)
            → ROUND_PLAY (per-game duration cap)
            → QUALIFY_FLASH (qualified/eliminated reveal, 4 s)
            → [next SHOW_INTRO | PODIUM]
PODIUM → LOBBY (crown ceremony + PLAY AGAIN / HOME)
```

State machine owned by `shared/domain` (architecture doc § 3). The v1 `ROUND_RESULTS` screen is superseded by `QUALIFY_FLASH`; `toPodium` becomes the reachable show ending.

## 6. Difficulty & Seeds

- Difficulty is a function of **round position**, not escalation tiers: the FINAL uses a harder variant (narrow course) by design. No infinite-run or tier systems (repealed).
- Every round generates a fresh `mapSeed` from `showSeed + roundIndex`; identical seed = identical course for all participants.

## 7. Show-Level Edge Cases (exhaustive)

### 7.1 Qualification boundary

The round ends at the **first instant** the alive/finished count reaches quota; everyone qualified at that instant is in. If a single event takes the field from above-quota to below-quota simultaneously (multi-elimination on one tick), the victims of that event **also qualify** (shared qualification) — the quota never silently shrinks.

### 7.2 Simultaneous final elimination

If both finalists are eliminated on the same tick, the crown is **shared** (both get `crownsWon`).

### 7.3 The human is eliminated mid-show

Remaining rounds resolve instantly: the summary shows the simulated show outcome (which bot wins) and the player's stats record the elimination (`showsPlayed` +1; `finalsReached` only if eliminated in the FINAL). Buttons: PLAY AGAIN / HOME.

### 7.4 Show abandonment

System back (or the exit control) during any round → confirm dialog (`TtrQuitDialog`) → on QUIT the show is abandoned: **no stats recorded** (not even `showsPlayed`), back to Home. Back at PODIUM/Home behaves per the ux-checklist matrix.

### 7.5 Backgrounding

The player's body goes idle; the round continues; auto-rejoin within the reconnect grace (network doc § 5.3 applies to future online shows; solo: the sim pauses nothing — bots keep playing).

### 7.6 One-player edge

Solo show always starts with bot fill to 4 seats (§ 9). If every bot is eliminated before the human, the show continues normally (quota rules don't depend on who the survivors are).

## 8. Scope

### 8.1 MVP (in)

- Solo shows vs 3 bots, 3-round structure, qualification + crown, podium ceremony.
- Crown stats (`crownsWon` / `finalsReached` / `showsPlayed`) + best-race-time side record.
- Local profile/settings/onboarding as shipped (v1 meta shell unchanged).
- **Multiplayer infra preserved but not user-facing** (server, protocol, host/remote code) — do not delete, do not wire.

### 8.2 Backlog (explicitly out)

- Random matchmaking, team games (Fall Guys mid-show team rounds), point-collection rounds (egg-hunt archetypes), spectator mode, chat, seasons, ranked, bot difficulty tiers.
- King of the Hill (occupancy archetype) — dormant design, revisit per roadmap.
- A third competitive archetype (the show uses two games + a variant for MVP; a third full game is trigger-gated per `docs/08-roadmap.md`).

## 9. Bots

- Solo shows fill to 4 seats: `bot-1..bot-3` / `BOT 1..3`, auto-ready, full participation — bots can qualify, eliminate the human, and win crowns.
- Behavior profiles per game live in the game docs (`docs/games/*.md` § Bot profile). Basic difficulty: beatable but not free.
- Bots never disconnect; nothing bot-related crosses the wire (host-side inputs).
