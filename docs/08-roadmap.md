# 08 — Post-Launch Roadmap

Direction, not commitment. Every item names its **trigger** — the observation that justifies starting it. No trigger, no build (YAGNI is law, `docs/05-conventions.md` § 7). Options were deliberately kept open at the architecture level (minigame-as-data, protocol versioning, server-as-library, `GameVerb.dash` reserved); picking among them is a post-launch, data-driven decision.

---

## 1. Candidate Themes

| Theme | Candidates | Trigger (start when...) | Cheap because |
|-------|-----------|--------------------------|--------------|
| **More minigames** | New race variants; redesigned occupancy game (King of the Hill revisit — "boring" verdict: diagnose hold-vs-pace first); dash-verb game (`GameVerb.dash` reserved) | Round-level retention shows one game dragging (players quitting on a specific minigame); or top request | Map = JSON; new archetype = 2 glue cases (`docs/02-architecture.md` § 3) |
| **Achievements & progression** | Quests, streaks, cosmetic unlocks (colors first — profile palette already exists) | D7 retention below target and play sessions are long (people want goals) | Local storage already in place (`ProfileStore`); no server work |
| **Random matchmaking** | Queue-based pairing, then MMR-lite | Invite-code rooms saturating; concurrent rooms near server cap | Room lifecycle + rate limits already tested; queue is a new server module |
| **Bot difficulty tiers** | Easy/normal/hard; per-seat difficulty | Solo win-rate skewed (near-0% or near-100% for typical players) | `BotBrain` is already the swap point (GDD § 9) |
| **LAN direct mode** | Host device embeds the relay server; QR/manual IP join | Offline-play demand (gatherings, weak networks) | Server is a pure Dart library — import and run in-app |
| **Seasons / ranked** | Weekly rotation, ladders | MAU justifies live-ops investment | Requires accounts first (see § 2) |
| **AFK handling / spectator polish** | Idle detection, auto-ready | Real multiplayer rooms with strangers (matchmaking era) | Netcode disconnect policies already cover the mechanics |

## 2. Deliberate Non-Goals Until Further Notice

- **Accounts**: every feature above is designed to work without them. Accounts arrive only when a feature is impossible locally (cross-device progression, real ranked) AND the privacy policy is revisited. Current no-collection stance (`docs/06-release-legal.md` § 2) is a product feature.
- **Chat**: strangers + chat = moderation obligations. Revisit with matchmaking at the earliest.
- **Ads beyond interstitial-between-rounds** (M5 scope): no rewarded video, no banners mid-game, until revenue data says otherwise.

## 3. Standing Principles for Future Work

1. Trigger first: the roadmap item starts with its measurement in place (analytics event or store metric), not with code.
2. One milestone at a time; DoD gates apply (`docs/05-conventions.md` § 6).
3. Bible rules are not suspended for new features — new mechanics get GDD rules first, same commit as implementation (AGENTS § 6.8).
4. Protocol changes ride the N/N-1 rule; never force-update clients for a game-content addition.
