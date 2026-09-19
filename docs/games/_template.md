# Game Spec — _template

Copy this file per game (`docs/games/<game-id>.md`). Every section is mandatory; write "N/A — reason" if truly inapplicable. The compliance review (AGENTS § 10) checks games against these documents section by section.

---

## Identity

- **Game id**: `<snake_case>` (matches `MiniGameId`)
- **Verb** (single button): `JUMP` / `HOLD` / `SWITCH` / ...
- **Automatic behavior**: what the character does without input
- **Show slots**: which rounds this game fills (R1 / R2 / FINAL / variants)

## Qualification

- **Quota rule**: exactly how players qualify (order / survival / count)
- **Round end conditions**: first-true instant wins (GDD § 7.1 boundary rule)
- **Timeout rule**: how the quota fills if time runs out

## Level design

- **Layout**: zones/segments in order, distances, widths
- **Hazards**: each hazard's behavior, timing windows, elimination condition
- **Variant(s)**: per-show-slot differences (e.g. FINAL narrow course)

## Map data schema

- JSON fields the map carries (positions, sizes, hazard specs, seed-jitter ranges)
- `factory(mapSeed)` determinism statement

## Difficulty & seeds

- How round position affects this game (fixed per GDD § 6 — no tiers)
- Seed usage: what jitters, what stays fixed

## Bot profile

- Heuristic summary per archetype phase; named tuning constants live in code next to the brain (documented, per AGENTS § 6.4 note)

## Art & Audio

- **Visual spec**: jelly-casual vector treatment (shapes, faces, animation states) mapped to `ArenaPalette` tokens (design guide § 9.2)
- **Audio cues**: moment → sound id (shared ids + loop ids per design guide § 9.4)

## Edge cases (game-level)

- Exhaustive list beyond GDD § 7 (simultaneous events, geometry traps, timeout corners)

## PATROL anchors

- Visible strings this game contributes (testing law § 9 list — same-commit rule)
