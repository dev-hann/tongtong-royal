# Game Spec — Hammer Dodge (`hammer_dodge`)

The show's survival archetype: ROUND 2 (3 players, quota: last 2 alive). Fall Guys benchmark: "Tip Toe Fallout / Block Party" energy — shrinking ground, accelerating sweepers.

> Implementation note: this game shipped in v1 and was deleted in the 2026-09-19 scope reset. Revive from git history (resolver, arena, builder, survival bot, steering — last present before commit `a6b1d81`) and re-fit to this spec; do not re-derive from scratch.

## Identity

- **Game id**: `hammer_dodge`
- **Verb**: `JUMP`
- **Automatic behavior**: drift toward the arena center (auto-center; guide § 3)
- **Show slots**: ROUND 2 only

## Qualification

- **Quota (nominal 3 players → 2; tolerates 4 starters** when R1 over-qualifies, GDD § 4 note): the round ends the instant only 2 players remain alive; survivors qualify, everyone eliminated before that instant is out.
- **Qualified order** (crossing case): survivors first (in life order), then the crossing event's victims in elimination order.
- **Boundary rule**: GDD § 7.1 applies literally — if one event eliminates multiple players crossing the quota (3 alive → 1 in one tick), the victims of that event ALSO qualify (shared qualification). The FINAL then starts with 3 runners (see `trap-race.md` § FINAL: supports 2–3 starters; quota always 1).
- **Timeout (60 s)**: all remaining survivors qualify (shared) — survival IS the qualification.
- Elimination: hammer contact or falling off the platform. No respawn, no second chances.

## Level design

Circular platform (radius 7 m, 16-segment), kill ring beyond the rim, 2 rotating hammer arms at pivot center:

- Arms sweep at different radii bands (6.9 m / 7.1 m — ankle height) and **counter-rotate** (1.2 / −1.7 rad/s base) so the platform has no permanent safe spot.
- **Shrink phase** (v2 addition): from 30 s the rim shrinks (radius 7 → 4.5 m over 15 s; kill ring follows) — standing room tightens, forcing contact.
- Spawns: 3 slots spread on the upper arc; idle-safe for ≥ 5 s (no input, no elimination).

## Map data schema

`HammerArenaMap` JSON: platform radius + shrink schedule, kill ring margin, hammers[{radius band, speed, phase}], spawns[]. Seed jitters speeds (±0.25 rad/s) and phases (±30°). Deterministic factory.

## Difficulty & seeds

Fixed per GDD § 6 (single slot = single tuning). No in-round escalation beyond the designed shrink phase (which is level design, not a difficulty system).

## Bot profile

Center-drift with wander (avoid stacking), jump when an arm's predicted tip crosses the bot's position within 25 ticks (linear extrapolation), quiet-core stillness near pivot. Documented constants live in the revived `survival_bot.dart`.

## Art & Audio

- **Visual**: jelly dodgers (panic eyes when an arm nears, wobble on jump); hammer arms are giant faced mallets (angry brows) leaving smear arcs; the platform is a chunky layered disc with a stitched rim that visibly frays as it shrinks (segments drop with dust puffs); the kill ring reads as a dark aura gradient. Vector-only, `ArenaPalette` tokens.
- **Audio cues**: `jump`, hazard whoosh per arm pass, rim-shrink rumble (loop-synth), `fail` per elimination, `finish` sting when the quota closes.

## Edge cases (game-level)

- Same-tick multi-elimination crossing quota → shared qualification (§ above / GDD § 7.1).
- All alive players eliminated on one tick → all share qualification (GDD § 7.1 degenerate case: the eliminating event's victims qualify alongside survivors).
- Hammer-arm overlap double-hit on one player → single elimination event (idempotent by playerId).
- Shrink phase never eliminates by itself — only hammer contact or falling off the (shrinking) rim does.

## PATROL anchors

`Last two standing qualify` (intro rule), `JUMP`, plus show-level: `QUALIFIED`, `ELIMINATED`.
