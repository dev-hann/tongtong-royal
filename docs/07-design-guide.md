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

## 2.1 Iconography

- **Set**: Phosphor Icons, **Fill** weight — rounded, chunky, matches the Fredoka toy-box personality. Stock Material outlined icons are forbidden in UI chrome. App code accesses glyphs via `TtrIcons.*` (`app/lib/design/ttr_icons.dart`): `phosphor_flutter` 2.1.0 (latest) subclasses `IconData`, which is `final` on the pinned Flutter SDK, so its Dart API cannot compile — `TtrIcons` declares the same Fill codepoints against the package's bundled font.
- Sizes: 24 (rows), 28 (home entries), 32+ (hero moments). No ad-hoc sizes.
- Colors: `neutral700` default, `primary` for the single emphasized icon per screen. Never player colors on icons.
- Icon + label pairs: icon color matches its label style; both come from tokens.
- The Material icons font stays bundled (`uses-material-design: true`) for framework-internal glyphs; app code uses Phosphor.

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
| **Verdict reveal** | QUALIFY_FLASH: each player chip drops in staggered (entrance rule), verdict-colored (qualified=success, eliminated=danger); champion reveal = crown pop (§ 4 pop + one pulse). |

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
| Destructive confirm (quit race) | `TtrQuitDialog` (tokened AlertDialog + `TtrButton` actions; **safe action carries primary, destructive stays secondary — anti-misclick convention**; **actions fill the row as equal stretched buttons — never right-clustered**) | raw `AlertDialog` with default styling; danger-colored destructive buttons; right-clumped actions |
| Route back affordance | `TtrBackButton` (left caret, top-left header) | text-only "< Back" or bare edge swipe |
| Podium finish (crown ceremony) | Crown podium: champion center-tall with crown + pulse (one pulse rule), co-champions side-by-side (GDD § 7.2), eliminated chips small below | flat ranked list; points/standings lists |

**BAD**: `Text('2nd', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))` — no font token, no tracking, no entrance, spreadsheet numeral.
**GOOD**: `Text('2nd', style: TypeScale.display)` inside a staggered pedestal with `PlayerPalette` color block.

## 6. Screen Layout Patterns

**The Non-Game Form Law (absolute — violations are review blockers, AGENTS § 10).** Every screen outside the game world (HUD/play rendering) follows EXACTLY ONE of two archetypes. No third layouts, no per-screen improvisation. **One exemption: the elimination SUMMARY screen** (GDD § 7.3 — simulated outcome list + terminal actions) — body exempt from the FORM skeleton by design.

- **A. FOCUSED** (single-purpose, no chrome): centered vertical column, no header, no scroll. Applies to: **Home, Round Intro, Results header zone**.
- **B. FORM** (meta pages with content): `TtrPageHeader` (fixed, back + centered title, `SpacingScale.lg` padding — never inside the scroll area) + ONE scrollable body (`horizontal: SpacingScale.xl`) whose content appears ONLY inside `TtrCardGroup` sections (section label + card rows), actions full-width (`CrossAxisAlignment.stretch`), optional bottom-pinned footer. Applies to: **Profile, Settings, Credits, Onboarding** — and every future meta page.

Shared mandates for both archetypes: `TtrPageShell` surface, SafeArea-protected content, all spacing/typography/icons from tokens (no raw sizes — avatars use the tokenized size), staggered entrance on every list/grid/section (§ 4), one pulsing element maximum.

Screens:

- **Home** (FOCUSED): centered column — logo (two-tone display), tagline, stacked actions (PLAY SOLO primary large, FRIENDS secondary disabled + chip). Ambient backdrop. **Entry points: profile avatar top-left, settings gear top-right** (SafeArea-protected corners).
- **Lobby**: reserved for the multiplayer rebuild (MVP Home replaces it) — seat card grid 2×2 centered, actions bottom.
- **Show/Round Intro** (FOCUSED): vertical rhythm — ROUND n / 3 pill, game banner (name + rule line + verb), giant countdown. Backdrop tinted to the game's arena family.
- **Play**: full-bleed world; HUD strip top (standings), timer badge bottom under the world, single action button bottom-center (bottom viewPadding-aware). (Game world — the Form Law does not apply here.)
- **QUALIFY_FLASH** (FOCUSED, 4 s auto-advance): verdict reveal — per-player chips staggered, `QUALIFIED` (success) / `ELIMINATED` (danger) verdict text, quota counter (e.g. `2 / 3 QUALIFIED`). The FINAL's flash is the **crown moment**: champion reveal with crown pop; shared crown shows both champions.
- **Elimination summary** (exempt archetype): the human is out — own verdict, simulated show outcome (which bot wins the crown, one line), stat deltas, PLAY AGAIN primary + HOME secondary.
- **Podium — crown ceremony** (FOCUSED): champion center-tall, crown + single pulse, co-champion pair when shared; `PLAY AGAIN` primary + `HOME` secondary.
- **Profile** (FORM): `[IDENTITY]` avatar + nickname field + SAVE / `[COLOR]` palette grid / `[RECORD]` stats cards.
- **Settings** (FORM): `[GENERAL]` sound toggle / `[ABOUT]` credits row; version footer bottom-pinned.
- **Credits** (FORM): attribution rows in cards, body type.

## 7. Fonts & Licensing

Fredoka and Nunito are SIL OFL, bundled as `.ttf` assets in `app/assets/fonts/` (offline-first rule — no runtime font fetching). Every font file gets a row in `ATTRIBUTION.md` before it ships. New fonts must follow this guide's role table or the guide must change first (same commit).

**Static instances only (hard rule)**: bundle one static `.ttf` per weight with pubspec `weight:` mappings. Variable-font TTFs are forbidden — Flutter does not drive the `wght` axis from `fontWeight` (flutter/flutter#74643), so all weights render as the default instance and the hierarchy collapses. Incident 2026-09-19.

## 8. Accessibility & Fullscreen Notes

- **Immersive fullscreen**: the app hides status and navigation bars (`SystemUiMode.immersiveSticky`, portrait-only). Backdrops/world render edge-to-edge; **content always sits inside SafeArea** — hidden bars do not remove display cutouts (punch-hole cameras). Bottom-anchored controls add `MediaQuery.viewPaddingOf(context).bottom` on top of their visual margin.
- Contrast: player colors are WCAG-checked against arena background (tokens test enforces).
- Touch targets ≥ 88px for the action button, ≥ 56px standard buttons.
- Reduced-motion support: backlog (not in MVP).

## 9. Game Art & Audio (jelly-casual, vector-first)

**Direction**: the game world speaks the same toy-box language as the shell — jelly blobs with faces, chunky hazards with attitude. **Vector-first hard rule**: all in-game art is code-drawn (Flame canvas painters in `design/game_art/`); raster sprites ship only when a future decision says so (then `assets/art/` + ATTRIBUTION law applies).

### 9.1 Character language

- Players are **jelly blobs**: `PlayerPalette` body color, two-dot eyes (blink state), squash-and-stretch on jump/land (motion § 4 scales), ragdoll spin on elimination. The local player keeps the white ring from the shell.
- Hazards have **faces**: hammers/mallets carry simple angry-brow eyes; menace reads from shape + face, never gore.
- Faces are 2–4 primitives max — readable at thumbnail size.

### 9.2 Palette & shape law

- All art colors come from `ArenaPalette` (or `PlayerPalette`) — the same tokens the shell uses. No free colors in painters.
- Shapes: rounded everything (radius scale); hazard edges may go chunky-jagged only for the kill/void language (dark aura gradients, warning stripes on pit lips).

### 9.3 Feedback art

- Every game event gets a visual: elimination = pop + puff particles, qualification = burst at the player, crown = podium ceremony (guide § 6 patterns).
- Motion smear arcs on sweeping hazards (cheap, legible speed).

### 9.4 Audio

- Cue table per game doc (`docs/games/*.md` § Art & Audio); shared ids: `ui_tap`, `jump`, `finish`, `fanfare`, `fail` (+ per-game loops).
- Loop cues: `hazard_whoosh` (hammer pass), `rim_shrink` (platform shrink rumble), `victory_loop` (crown ceremony bed).
- Current SFX are ffmpeg-synthesized placeholders (release checklist row: swap for CC0 before store); every audio file carries an ATTRIBUTION row — synthesized or sourced, no exceptions.
