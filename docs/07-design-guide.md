# 07 — Design Guide

The visual language bible. Every screen, component, and animation follows this document. Priority chain: `AGENTS.md` > docs > README. Token rules live in `docs/05-conventions.md` § 2; this document defines the *language* the tokens express.

---

## 1. Personality

**TongTong Royal is a toy box.** Bouncy, chunky, celebratory. Think jelly, not chrome.

Three principles:

1. **Everything responds.** Nothing appears static. Lists stagger in, numbers pop on change, buttons squash on press. A screen that doesn't move feels broken.
2. **Chunky over subtle.** Big shapes, big type, bold color blocks. If a highlight can be 4px or 12px, it is 12px. Rounded corners everywhere (radius scale, never sharp).
3. **Celebrate the player.** Wins are loud (podium pulse, trophy), losses are gentle (soft tones, quick transitions). Never punish with harsh red flashing.

## 2. Typography

| Role | Font | Weights | Used for |
|------|------|---------|----------|
| **Display** | Fredoka | 500-700 | Logo, countdown numerals, podium ranks, score numbers, button labels, badges |
| **Body** | Nunito | 400-800 | Rule one-liners, player names, lists, standings, toasts, helper text |

Rules:

- Korean text falls back to the system font automatically (Fredoka/Nunito have no Hangul); latin-first surfaces (numbers, JUMP/DASH, TONGTONG ROYAL) carry the game identity regardless.
- Button/label text: UPPERCASE + `TypeScale.labelTracking` letter spacing. Never title-case a button.
- Numbers in HUD/podium always Fredoka SemiBold — Nunito numerals read as "spreadsheet".
- One font family per visual unit; never mix Fredoka and Nunito inside a single word/row label pair.

## 3. Color Usage

| Token family | Meaning | Never use for |
|--------------|---------|---------------|
| `primary` (orange) | Energy, main actions, local player emphasis | warnings |
| `secondary` (teal) | Support actions, accents, "coming soon" | danger |
| `PlayerPalette` | Player identity (seat colors) | UI actions — a button is never player-colored |
| `semantic` (success/danger/warning) | Status only (connected/disconnected, timer low) | decoration |
| `ArenaPalette` | In-game world rendering | shell/UI screens |

Backgrounds: shell screens light (`background`), game world dark (`ArenaPalette.background`) — the contrast is the immersion cue between menu and play.

## 4. Motion & Juice (the dynamics law)

Durations (tokens): `tap` 80ms · `countdownPop` 150ms · `transition` 240ms · `pulse` 900ms · `ambient` 12s.

| Pattern | Spec |
|---------|------|
| **Staggered entrance** | Lists/grids: items slide up + fade, 40ms apart, starting 80ms after screen build. Applies to seat cards, standings, placements, podium. |
| **Pop on change** | Any changing number (score, timer second, countdown) scales 1.0→1.15→1.0 over `countdownPop` on each change. |
| **Button press** | Scale to 0.96 on press-down, release back (80ms). All buttons, always. |
| **Pulse on emphasis** | Winner pedestal, "1st" chip, active round badge: repeating 1.0→1.04 scale at `pulse` period. One pulsing element per screen — more is noise. |
| **Screen transitions** | Fade + slide-up 240ms (TtrPhaseTransition). Direction always "upward energy". |
| **Ambient backdrop** | Slow drifting soft shapes (`ambient` loop) behind every shell screen — the "alive" floor. |
| **Score delta fly-in** | Round points appear as chips flying in staggered (entrance rule) next to standings. |

**Do not**: animate layout positions of interactive controls mid-tap (mis-taps), pulse more than one element per screen, or exceed 300ms for anything the user is waiting on.

## 5. Component Map (situation → component)

| Situation | Use | Don't |
|-----------|-----|-------|
| Primary action (start match, play) | `TtrButton` primary large | raw `ElevatedButton` |
| In-game single verb | `TtrActionButton` (tap-down fire) | `FloatingActionButton` |
| Player identity row | `TtrSeatCard` / `TtrPlayerChip` | raw `ListTile` |
| Ranked list | `TtrPlacementList` / `TtrStandingsList` (staggered) | hand-built columns |
| Countdown / big number | `TtrCountdown` (pops per second) | plain `Text` |
| Minigame announce | `TtrRoundBanner` under a `ROUND n / N` pill | unlabelled banner |
| Transient message | `TtrToast` | `SnackBar` |
| Podium finish | Pedestal row (2-1-3 heights, trophy pulse) | flat ranked list |

**BAD**: `Text('2nd', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))` — no font token, no tracking, no entrance, spreadsheet numeral.
**GOOD**: `Text('2nd', style: TypeScale.display)` inside a staggered pedestal with `PlayerPalette` color block.

## 6. Screen Layout Patterns

- **Home**: centered column — logo (two-tone display), tagline, stacked actions (PLAY SOLO primary large, FRIENDS secondary disabled + chip). Ambient backdrop. **Entry points: profile avatar top-left, settings gear top-right** (SafeArea-protected corners).
- **Profile**: avatar block (player color + nickname), nickname edit field, color palette grid (PlayerPalette swatches; selection ring = primary), stats cards row (matches / wins / 1st places — Fredoka numerals, staggered entrance). Local-only, no sync UI.
- **Settings**: grouped list — sound toggle, credits row, version footer. Primary-colored active toggle.
- **Credits**: scrollable attribution rows (asset name, source, license) — mirrors `ATTRIBUTION.md`, body type.
- **Lobby**: seat card grid 2×2 centered, match meta pill above (rounds, bot fill), actions bottom.
- **Intro**: vertical rhythm — round pill, banner, giant countdown. Nothing else. Backdrop tinted to the upcoming minigame's arena family.
- **Play**: full-bleed world; HUD strip top (standings + timer + round), single action button bottom-center (bottom viewPadding-aware).
- **Results**: header pill, placement list (staggered), standings with delta chips, auto-advance progress bar at bottom.
- **Podium**: pedestals bottom-heavy, winner center-tall pulsing; Rematch primary + Exit secondary below.

## 7. Fonts & Licensing

Fredoka and Nunito are SIL OFL, bundled as `.ttf` assets in `app/assets/fonts/` (offline-first rule — no runtime font fetching). Every font file gets a row in `ATTRIBUTION.md` before it ships. New fonts must follow this guide's role table or the guide must change first (same commit).

## 8. Accessibility & Fullscreen Notes

- **Immersive fullscreen**: the app hides status and navigation bars (`SystemUiMode.immersiveSticky`, portrait-only). Backdrops/world render edge-to-edge; **content always sits inside SafeArea** — hidden bars do not remove display cutouts (punch-hole cameras). Bottom-anchored controls add `MediaQuery.viewPaddingOf(context).bottom` on top of their visual margin.
- Contrast: player colors are WCAG-checked against arena background (tokens test enforces).
- Touch targets ≥ 88px for the action button, ≥ 56px standard buttons.
- Reduced-motion support: backlog (not in MVP).
