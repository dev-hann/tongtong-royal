# 01 — Game Design Document (GDD)

TongTong Royal: 2-4 player real-time physics minigame collection. Fall Guys-scale fun, pocket-scale scope.

---

## 1. Core Loop

```
Home → Create/Join room (invite code) → Lobby (players ready up)
  → [ Round 1..5: intro (3s) → play (60-90s) → results ]
  → Final podium → back to Lobby (rematch)
```

## 2. Round Structure & Scoring

- A match = **5 rounds**, each a different minigame instance (see §6 selection rule).
- Each round awards points by placement:

| Players in round | 1st | 2nd | 3rd | 4th |
|------------------|-----|-----|-----|-----|
| 4 | 4 | 3 | 2 | 1 |
| 3 | 3 | 2 | 1 | — |
| 2 | 2 | 1 | — | — |

- Points scale to the number of players *actually ranked in the round* (see §7.2 for leavers).
- Final ranking = cumulative points, descending. Podium shows 1st/2nd/3rd.

### 2.1 Final Tie-Break (exhaustive)

If two or more players tie on cumulative points:

1. Compare their **round placements from the last round backwards** (lexicographic, better placement wins): the player with better placement in Round 5 wins; if equal there, compare Round 4, then 3, 2, 1.
2. If placements were identical in every round, players **share the rank**. Shared rank consumes the next rank slot (two players sharing 1st → next player is 3rd).

## 3. Controls (one button, fully automatic movement)

Every minigame is **one-button with automatic movement** (hyper-casual standard). The single button's verb differs per game:

| Minigame | Button | Automatic behavior |
|----------|--------|--------------------|
| Trap Race | Jump | Auto-run: constant rightward movement |
| Hammer Dodge | Jump | Auto-center: drift back toward the arena center |

Rules:

- **One button per game.** No joystick, no d-pad, no second button.
- Movement is **fully automatic** — the player only times the single action.
- Internal representation is unchanged: clients translate (auto-steering + button edges) into the same `PlayerInputState` vector used since M1. Protocol, server, netcode, and bots are unaffected.
- Bot opponents (§ 9) are unaffected: they already produce input vectors directly.
- The dash verb remains in the input vocabulary (`GameVerb.dash`) for future minigames; no MVP game uses it.

## 4. MVP Minigames

Two archetypes (a third is planned post-MVP, § 8.2); one engine each, maps are data. Each minigame implements the shared `MiniGame` interface (see `docs/02-architecture.md` § Minigame Interface).

### 4.1 Trap Race (archetype: race)

- **Goal**: first to the finish line. Placement = finish order.
- **Course**: static platforms, rotating hammers (kinematic bodies), moving platforms, fall zones (kill volumes → respawn at last checkpoint).
- **Checkpoints**: crossing a checkpoint sets respawn point. Respawn keeps you in the race (no elimination).
- **Round end**: when all players finish, or timeout (90s) — see §7.4.

### 4.2 Hammer Dodge (archetype: survival)

- **Goal**: be the last player on the platform.
- **Arena**: circular platform surrounded by a fall zone. Rotating hammer arms sweep the platform at varying heights.
- **Ranking**: elimination order reversed = placement. First eliminated is last.
- **Round end**: one player remains, or timeout (60s) — survivors ranked by ... §7.5.

## 5. Round Flow States

```
LOBBY → ROUND_INTRO (3s, shows minigame name + rule one-liner)
      → ROUND_PLAY (60-90s per minigame)
      → ROUND_RESULTS (placement + points, 6s)
      → [next round] ... → PODIUM → LOBBY
```

State machine is owned by `shared/domain` (see architecture doc). Server relays state transitions; host triggers them.

## 6. Minigame Selection Rule

- A match is **3 rounds** drawn from the 2 minigames: **shuffled cycle** — shuffle the full list, deal rounds from it, reshuffle when exhausted; constraint: the first game of a new cycle must not equal the last game of the previous cycle.
- Seed comes from the host at round start and is broadcast (identical map variants for everyone, see network doc § Sequencing).
- With 2 games and 3 rounds the constraint forces strict alternation: B, A, B (or A, B, A).

## 7. Game-Rule Edge Cases (exhaustive — do not improvise beyond this list)

### 7.1 Start conditions

- Round 1 starts only when **all present players are ready** AND the **host presses Start**.
- Minimum 2 players to start a match. Below that, the room stays in lobby.

### 7.2 Player leaves mid-match

- The round **continues** with remaining players. Points for that round are scaled to the players *ranked at round end* (table §2).
- The leaver gets **0 points for the round they left and all remaining rounds**.
- The leaver is **excluded from the final podium** (treated as forfeit).
- Their physics body: remains in the world, idle (no input) for the rest of the current round, then removed from subsequent rounds. See network doc § Player Disconnect.

### 7.3 One player remains (everyone else left)

- The match **ends immediately**. The remaining player **wins** regardless of current points.

### 7.4 Race: nobody finishes by timeout

- At timeout, unfinished players are ranked by **forward progress distance** (furthest first), below all finishers.

### 7.5 Survival: timeout with multiple survivors

- Survivors ranked by **elimination order is undefined for them** → survivors share ranks by **time-of-last-contact-with-danger** is over-engineered; instead: all survivors at timeout share the best remaining rank equally (e.g. 2 survivors in a 4-player round → both 1st, both get 4pt; next rank skipped is irrelevant — nobody else remains above them).

### 7.6 Simultaneous finish (same tick)

- Players finishing on the same simulation tick **share the rank**; the next rank is skipped (two players share 1st → next finisher is 3rd).

### 7.7 All players fail / die simultaneously (survival)

- If all remaining players are eliminated on the same tick, they share the rank group of that elimination, in the order they were eliminated *before* this match rule applies: shared-tick eliminations are a shared rank.

### 7.8 AFK players

- **MVP: no AFK detection or handling.** Explicitly out of scope (backlog). Do not implement idle kicks, bots, or auto-ready.

### 7.9 Rejoining mid-match

- A leaver may rejoin the room during the same match via invite code within the reconnect grace window (network doc § Reconnect). They resume with their accumulated points; rounds missed during absence award 0 points. **If they missed the end of a round, that round counts as 0.** They cannot rejoin a match after the podium screen.

### 7.10 Host starts a round, then a player readies/unreadies

- Once `ROUND_INTRO` begins, ready state is frozen. Late/absent players are spectators until next round (they respawn into the next `ROUND_INTRO`).

## 8. Scope

### 8.1 MVP (in)

- 2-4 players, invite-code rooms, 3-round matches, 2 minigames (a 3rd is planned post-MVP), podium, rematch.
- **Bot fill** (§ 9): host-side bot players fill empty seats.
- Sound effects, best-score persistence (local), simple character customization (color).

### 8.2 Backlog (explicitly out — do not build)

- Random matchmaking, AFK handling, spectator mode, cosmetics beyond color, chat, seasons, ranked, bot difficulty tiers.
- **King of the Hill** — removed from MVP for pacing ("too boring" verdict); revisit as a redesigned occupancy archetype after launch polish.

## 9. Bot Players

### 9.1 Fill policy

- Host controls **bot fill** (toggle, default on in solo/early-service play). When enabled and humans < 4, bots fill seats to 4. Bots never displace humans.
- A bot's identity: `playerId` = `bot-1`..`bot-3`, nickname = `BOT 1`..`BOT 3`.
- Bots are auto-ready; they never block start conditions (§ 7.1 counts them as players — 1 human + bots satisfies the ≥ 2 minimum).
- Bots participate fully: placements, points, podium, tie-breaks — identical to humans. Podium/results mark them via nickname.
- Disconnect rules do not apply to bots (they cannot disconnect, idle, or AFK).
- Bots run **host-side**: the host client generates their inputs each tick and feeds them into its own simulation. Nothing bot-related crosses the wire — remote clients just see ordinary players in snapshots.

### 9.2 Behavior (difficulty: basic)

- Heuristic, archetype-aware steering. No pathfinding, no learning — predictable, fair-ish, occasionally clumsy (they are beatable by an average human).
- Common: bots act on their own pose + map data + tick only (no omniscience: they cannot read other players' future inputs; contact-level awareness of nearby bodies is allowed).
- Race: run toward the finish, jump when obstructed or at gaps (map-data driven), occasional dash.
- Survival: drift toward the arena center, jump/dash to avoid incoming hammers (contact-level detection of nearby hammer arms).
