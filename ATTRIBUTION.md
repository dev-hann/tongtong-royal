# Asset Attribution

Every asset (sprite, sound, font, map art) shipped in the app gets a row here **before** it is committed to the repo. See `docs/06-release-legal.md` § 3.

| Asset | Path | Source URL | License | Proof (date/notes) | Restrictions |
|-------|------|-----------|---------|--------------------|--------------|
| Fredoka font | app/assets/fonts/Fredoka.ttf | github.com/google/fonts (ofl/fredoka) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Fredoka.txt | Reserved Font Name per OFL |
| Nunito font | app/assets/fonts/Nunito.ttf | github.com/google/fonts (ofl/nunito) | SIL OFL 1.1 | 2026-09-19; OFL copy at assets/fonts/OFL-Nunito.txt | Reserved Font Name per OFL |
| Phosphor Icons | pub: phosphor_flutter | phosphoricons.com / github.com/phosphor-icons/web | MIT | 2026-09-19; Fill weight used | notice file per MIT |

Rules:
- CC0 preferred. CC-BY requires in-app credit (settings → Credits).
- Unknown license = not shipped. Delete it.
- AI-generated: record generator + date.
