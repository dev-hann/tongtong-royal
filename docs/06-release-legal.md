# 06 — Release, Legal & Compliance

Checklist document. Nothing ships until its boxes are ticked. Legal requirements are edge cases with lawyers attached — treat misses as release blockers.

---

## 1. Game Rating (South Korea — GRAC)

- Any game distributed in Korea requires a rating classification by GRAC (게임물등급위원회).
- TongTong Royal profile: no violence beyond cartoon physics, no gambling, no real-money trading, no chat between strangers → candidate for **취약등급 (weak/simple game classification)** or equivalent low-cost path.
- Verify current process at release time: rules change. Check grac.or.kr before M5.
- Google Play additionally requires the Play rating questionnaire; Apple uses its own questionnaire — both must match GRAC-equivalent answers.

**Blocker**: no Korean store listing without rating classification evidence in this repo (`docs/legal/` folder).

## 2. Privacy

| Item | Requirement |
|------|-------------|
| Privacy policy URL | Mandatory for both stores. Host on GitHub Pages from this repo (`docs/legal/privacy.md` → published page) |
| Data collected | Enumerate honestly: crash reports (if Sentry enabled), ads (Google AdMob identifiers). MVP goal: collect nothing |
| Ads | If `google_mobile_ads` ships: policy must disclose advertising ID usage; include AdMob's own policy links |
| Accounts | None (invite codes, no login). Keep it that way for MVP — every account feature multiplies privacy surface |
| Age gate | Stores' "designed for children" declaration: declare accurately; casual physics game ≠ child-directed unless marketed so. If declared child-directed: stricter ad limits apply — avoid the declaration by marketing to general audiences |

## 3. Asset Licensing

- **Every asset (sprite, sound, font) gets a row in `ATTRIBUTION.md`** at repo root: what, source URL, license, proof (screenshot/download date), restrictions.
- Preferred sources: CC0 (itch.io free, kenney.nl, freesound CC0). CC-BY requires visible credit text in-app (settings screen "Credits").
- AI-generated assets: record the generator + prompt date. Some stores require disclosure.
- **Blocker**: CI-adjacent release checklist includes "ATTRIBUTION.md complete, zero unknown sources" — an unattributable asset is deleted, not shipped.

## 4. Store Checklists

Pre-build sanity (learned from the 2026-09 icon incident — Material icon font silently missing; the 2026-09-19 review — doc drift after scope changes; and the 2026-09-19 device QA — variable fonts collapsing weights and pushed routes showing the black barrier):

- [ ] `app/pubspec.yaml` contains `flutter: uses-material-design: true`
- [ ] All bundled assets listed in `ATTRIBUTION.md` (fonts, icons, art, sound) **and rendered in the in-app credits**
- [ ] Generated placeholder SFX (ATTRIBUTION "PLACEHOLDER" rows) replaced with a sourced CC0 pack (Kenney) — placeholders must not ship
- [ ] GDD core-loop diagram + design-guide screen patterns match the implemented flow (post-scope-change drift check)
- [ ] Fonts are **static weight instances** with pubspec weight mappings (no variable TTFs — ux-checklist § 6)
- [ ] Pushed screens use `TtrPageShell` (opaque background — ux-checklist § 3)
- [ ] `AndroidManifest.xml` activity has `android:screenOrientation="portrait"` (ux-checklist § 4)
- [ ] Device smoke passed on the Pi rig (`scripts/smoke_device.sh 192.168.0.5:5555`, testing doc § 9) — Pi is the ONLY test device

### Google Play

- [ ] Developer account ($25 one-time)
- [ ] Package `com.tongtong.royal`, signed release AAB
- [ ] Rating questionnaire done (consistent with GRAC)
- [ ] Privacy policy URL live
- [ ] Data safety form matches privacy policy exactly
- [ ] Screenshots, feature graphic, description (EN + KO)

### App Store

- [ ] Apple Developer Program ($99/year)
- [ ] Same bundle id, signed archive, TestFlight pass first
- [ ] Privacy nutrition labels matching policy
- [ ] Age rating questionnaire

## 5. Server Release (Fly.io)

- App: `tongtong-server`, region nearest majority of players (ap-northeast for KR).
- Config in-repo: `fly.toml` in `server/`. Secrets via `fly secrets`, never in repo.
- Free tier sufficiency reviewed at M5 (room count vs memory: rooms are an in-memory map — measure one room's footprint in integration tests first).
- Drain behavior per network doc § 8 (server shutdown) tested before store release.

## 6. Crash Reporting & Observability

- Sentry (free tier) enabled at M5, gated behind a first-launch consent screen if policy requires it (general audience: recommended).
- Server logs: structured (JSON), room lifecycle events at info, protocol violations at warn with payload summary (truncated).
- No PII in logs — playerIds are UUIDs, nicknames logged truncated.

## 7. Release Records

Every store release appends to `docs/legal/release-log.md`: version, date, rating evidence links, privacy policy version, asset audit result. If it isn't logged, it didn't happen.
