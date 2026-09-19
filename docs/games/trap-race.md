# Game Spec — Trap Race (`trap_race`)

The show's race archetype: R1 (4-player qualifier) and the FINAL (2-player crown duel). Fall Guys benchmark: "Dizzy Heights / Slime Climb" energy — readable hazards, fair gaps, one-button timing.

## Identity

- **Game id**: `trap_race`
- **Verb**: `JUMP`
- **Automatic behavior**: constant rightward run (auto-run; guide § 3 controls)
- **Show slots**: ROUND 1 (standard course) + FINAL (narrow variant)

## Qualification

- **R1 (4 players, quota 3)**: the first 3 players to cross the finish line qualify; the 4th is eliminated. Falls respawn at the last checkpoint (R1 HAS respawn — elimination only by final rank).
- **FINAL (2–4 players, quota 1)**: first finisher wins the **crown**. NO respawn — falling is elimination; when one remains alive (others fell), that survivor wins by survival. Simultaneous final elimination (all remaining fall on one tick) = shared crown (GDD § 7.2). The variant supports 2–4 starters (GDD § 7.1 cascade; spawns scale with field).
- **Round end**: the first instant the quota is met (GDD § 7.1). In the FINAL, a fall that leaves one alive ends the round instantly.
- **Timeout (R1 cap 90 s; FINAL cap 60 s)**: R1 — unfinished players rank by forward progress (furthest first); the quota fills in that order (progress ties share). FINAL —timeout ranks by progress; the leader takes the crown (shared on exact tie).

## Level design

Standard course (R1), in segments:

1. **Runway** (~12 m flat): safe start, verb affordance.
2. **Gap lane** (~20 m): 2 pit gaps (widths 1.5 m / 2 m) — jump-timed, fall → checkpoint respawn.
3. **Hammer alley** (~18 m): 2 rotating hammers sweeping the lane (speed 1.2 rad/s, phase-offset), one elevated safe lane requiring a jump onto a 1 m platform.
4. **Squeeze gates** (~14 m): 2 moving walls (sinusoidal, amplitude 1.5 m) forcing stop-start rhythm (auto-run makes timing windows the challenge).
5. **Final stretch + finish sensor** (~10 m downhill): celebration runway.

FINAL variant (`trap_race_final`): segments 2–4 only, lane width reduced 60%, gaps widened to 2.5 m, hammer speed 1.6 rad/s, no checkpoints.

## Map data schema

`CourseMap` JSON: spawn point, checkpoints[], kill volume Y, finish X, hammers[{pivot, radius, speed, phase}], walls[{x, amplitude, period}], platforms[]. Seed jitters hammer pivots (±0.5 m), wall phase (±0.25 period), gap width (±0.2 m). `factory(mapSeed)` is deterministic: same seed → identical course.

## Difficulty & seeds

Fixed per GDD § 6: R1 standard, FINAL narrow variant — no in-round escalation. `mapSeed = f(showSeed, roundIndex)`.

## Bot profile

Run-right, jump at gaps/obstacles within look-ahead 2.5 m (map-data driven), stuck-recovery jump+dash, occasional dash. Beat-able: bots misjudge jittered gaps rarely (tuned constants documented in `race_bot.dart`).

## Art & Audio

- **Visual**: jelly runners (player-palette body, blink + squash on jump/land, ragdoll spin on fall); hammers are chunky faced mallets (menace face) sweeping with motion smear arcs; gaps read as darker pit gradients with warning-striped lips; finish = checkered arch with burst particles (token warning color). All shapes vector-drawn from `ArenaPalette` (guide § 7).
- **Audio cues**: `jump` (tap), `finish` (qualifier sting), `fanfare` (crown), `fail` (final fall), hazard whoosh on hammer pass (loop-synth).

## Edge cases (game-level)

- Same-tick finishes each hold a qualifying slot (GDD § 7.1 — quota never shrinks; the next round may receive one extra player, which its spec supports).
- Checkpoint respawn preserves race position — respawned players never advance past the checkpoint they died at.
- A fall during the qualifying instant still counts: the finish sensor order at that tick is final.
- FINAL shared-fall: both bodies get elimination events on one tick → crown shared (GDD § 7.2), both get `crownsWon`.
- Hammer contact = elimination in FINAL (vs. checkpoint respawn in R1) — variant rule, not physics change.
- FINAL counts every elimination-class event (`PlayerFell` AND `PlayerEliminated`) as out — no-respawn means all falls are final.

## PATROL anchors

`First to the finish line` (intro rule), `JUMP`, plus show-level: `QUALIFIED`, `ELIMINATED`, `CROWN`.
