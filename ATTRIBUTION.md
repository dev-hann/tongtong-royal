# Asset Attribution

Every asset (sprite, sound, font, map art) shipped in the app gets a row here **before** it is committed to the repo. See `docs/06-release-legal.md` § 3.

| Asset | Path | Source URL | License | Proof (date/notes) | Restrictions |
|-------|------|-----------|---------|--------------------|--------------|
| Fredoka 400 | app/assets/fonts/Fredoka-400.ttf | github.com/google/fonts (ofl/fredoka) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Fredoka.txt | Reserved Font Name per OFL |
| Fredoka 500 | app/assets/fonts/Fredoka-500.ttf | github.com/google/fonts (ofl/fredoka) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Fredoka.txt | Reserved Font Name per OFL |
| Fredoka 600 | app/assets/fonts/Fredoka-600.ttf | github.com/google/fonts (ofl/fredoka) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Fredoka.txt | Reserved Font Name per OFL |
| Fredoka 700 | app/assets/fonts/Fredoka-700.ttf | github.com/google/fonts (ofl/fredoka) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Fredoka.txt | Reserved Font Name per OFL |
| Nunito 400 | app/assets/fonts/Nunito-400.ttf | github.com/google/fonts (ofl/nunito) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Nunito.txt | Reserved Font Name per OFL |
| Nunito 600 | app/assets/fonts/Nunito-600.ttf | github.com/google/fonts (ofl/nunito) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Nunito.txt | Reserved Font Name per OFL |
| Nunito 700 | app/assets/fonts/Nunito-700.ttf | github.com/google/fonts (ofl/nunito) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Nunito.txt | Reserved Font Name per OFL |
| Nunito 800 | app/assets/fonts/Nunito-800.ttf | github.com/google/fonts (ofl/nunito) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Nunito.txt | Reserved Font Name per OFL |
| Phosphor Icons | pub: phosphor_flutter | phosphoricons.com / github.com/phosphor-icons/web | MIT | 2026-09-19; Fill weight used | notice file per MIT |
| SFX: ui_tap | app/assets/sfx/ui_tap.ogg | generated (ffmpeg sine synthesis, 2026-09-19) | CC0-equivalent (self-generated) | PLACEHOLDER — replace with Kenney "Interface Sounds" (CC0) before store release | none; must be swapped |
| SFX: jump | app/assets/sfx/jump.ogg | generated (ffmpeg sweep synthesis, 2026-09-19) | CC0-equivalent (self-generated) | PLACEHOLDER — replace with Kenney CC0 pack before store release | none; must be swapped |
| SFX: finish | app/assets/sfx/finish.ogg | generated (ffmpeg two-tone synthesis, 2026-09-19) | CC0-equivalent (self-generated) | PLACEHOLDER — replace with Kenney CC0 pack before store release | none; must be swapped |
| SFX: fanfare | app/assets/sfx/fanfare.ogg | generated (ffmpeg arpeggio synthesis, 2026-09-19) | CC0-equivalent (self-generated) | PLACEHOLDER — replace with Kenney CC0 pack before store release | none; must be swapped |
| SFX: fail | app/assets/sfx/fail.ogg | generated (ffmpeg descending sweep, 2026-09-19) | CC0-equivalent (self-generated) | PLACEHOLDER — replace with Kenney CC0 pack before store release | none; must be swapped |

Rules:
- CC0 preferred. CC-BY requires in-app credit (settings → Credits).
- Unknown license = not shipped. Delete it.
- AI-generated: record generator + date.
