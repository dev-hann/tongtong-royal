# 04 — Network Edge Cases & Netcode Rules

This document is the complete policy for everything that crosses the wire. When reality presents a case not covered here, the procedure in `AGENTS.md` § 6.8 applies: add the rule here first (same commit), then implement.

---

## 1. Rates & Timing

| Channel | Rate | Notes |
|---------|------|-------|
| Client input upload | 30 Hz per client | Joystick vector + jump/dash edges, each with `seq` |
| Host snapshot broadcast | 20 Hz | Full player state for ≤ 4 players, host `tick` included |
| Global tick | Integer, incremented by host at fixed simulation rate | Never resets mid-match |
| Client render | vsync | Interpolated between the two most recent snapshots (**100 ms render delay**, i.e. render at tick T-2 while buffering T and T-1) |

Sequencing: **inputs and snapshots carry independent `seq`/`tick` counters.** On each channel, later wins: a snapshot with tick ≤ last-applied tick is dropped; an input with seq ≤ last-applied is dropped. WebSocket preserves per-connection order — no reordering handling beyond this.

**Input attribution**: the server stamps the sending connection's `playerId` onto every `PlayerInputMessage` before relaying it to the host (clients do not self-attest; the connection registry is the source of truth per the trust model § 3).

## 2. Handshake & Versioning

1. Client connects, sends `Hello { protocolVersion, playerId (client-generated UUID), nickname }`.
2. Server accepts N or N-1 (architecture doc § 7). Older → `VersionMismatch` and close. Newer (server outdated) → same message with "update server" note.
3. **Implicit accept**: a valid `Hello` with no `VersionMismatch` reply means accepted. There is no dedicated OK message; the next server traffic (e.g. `RoomSnapshot`) confirms liveness.
4. Join room: `JoinRoom { code }` or `CreateRoom`. Server replies `RoomSnapshot` on success, or `JoinFailed { reason: notFound | roomFull }` on failure (join and rejoin alike).
5. **Rejoin-ack timeout**: `RejoinRoom` without a `RoomSnapshot` reply within 5 s → client treats the rejoin as failed (terminal `needsManualRejoin`); no infinite parking.

## 3. Trust Model (explicit scope)

- The host is authoritative for **simulation and judging**. A malicious host can cheat. **This is accepted risk**: friends-only game, invite-code rooms. Anti-cheat is out of scope (backlog).
- The server performs **sanity bounds only**, not judging:
  - Input message rate cap per connection (drop excess, log).
  - Input values clamped server-side before relay (joystick ∈ [-1,1]²; no NaN/Inf).
- Clients **never** accept rules decisions from any source except host snapshots/events relayed via server. A client receiving a rules claim in any other message ignores it (defect if it exists).

## 4. Round Seeding

- At `ROUND_INTRO`, host generates `roundSeed`, broadcasts via `RoundStarting { roundIndex, minigameId, mapSeed, timeoutMs }`. All clients build identical map variants from `minigameId + mapSeed`.
- The map/obstacle layout data lives in the app package; the seed selects variants. No layout data crosses the wire.

## 5. Disconnect & Reconnect Policy

### 5.1 Host disconnect

1. Server detects socket close → room enters `HOST_GRACE` (10 s). All clients show countdown UI; the round **freezes** (host was the simulator; nothing advances).
2. Host reconnects within grace (same `playerId`, `RejoinRoom { code }`) → host receives buffered state snapshot (last host snapshot cached by server), simulation resumes.
3. Grace expires → room ends. Clients receive `RoomClosed { reason: hostLeft }` and return to home with an explanatory toast.

### 5.2 Non-host player disconnect

1. Socket closes → server marks player `disconnected`, starts the same 10 s grace. **Round continues.**
2. Their body stays in the world, idle: no input applied. Host applies idle physics; if they fall, checkpoint respawn applies; if the round ends, they score 0 and are excluded from the podium (GDD § 7.2).
3. Reconnect within grace → `RejoinRoom`, receive latest snapshot, resume sending inputs mid-round.
4. Grace expires → player removed from room; GDD § 7.2 applies for the rest of the match (they may still rejoin the *room* before the podium as a spectator→next-match participant, but the current match is forfeit for them).

### 5.3 Mobile backgrounding (critical)

- OS suspends the app → the socket dies. This is **not** an error path; it is the common path.
- Client infra detects lifecycle (`AppLifecycleState.paused`) and immediately initiates clean disconnect; on `resumed`, auto-`RejoinRoom` without user interaction if within grace.
- While backgrounded, the player is treated exactly like § 5.2 step 2 (idle body, round continues).

### 5.4 Reconnect spam

- Per-IP join rate limit: max 10 join/rejoin attempts per minute; excess connections receive `RateLimited` and are dropped. Room creation: max 5/min per IP.

## 6. Degraded & Adversarial Network Conditions

| Condition | Policy |
|-----------|--------|
| Malformed JSON / schema violation | Server validates every message against `shared/protocol` typed models; invalid → drop + log, **never crash**, no reply |
| Oversized message | Hard cap 4 KB. Over cap → disconnect that socket (log). |
| Input flooding within rate cap | Server relays but host applies only inputs within its tick window; excess discarded |
| Snapshot starvation (client) | No snapshot for 2 s → show "unstable connection" banner, freeze interpolation (hold last state). Recovery: resume from next snapshot, snap to it |
| Latency > 300 ms | Client shows ping warning only. **No kick, no throttling** (friends game principle) |
| Duplicate join (same playerId, second socket) | First socket wins; second receives `AlreadyConnected` and is closed |
| Message during state transition (race) | Every message is processed **only if valid for the current room state** (state machine owns filtering); otherwise dropped + logged. Examples: `StartMatch` from non-host → drop; input during `ROUND_RESULTS` → drop |

## 7. Message Size Budget

- Snapshot ≤ **2 KB** for 4 players. If exceeded, format must be redesigned (delta encoding / quantization) — do not silently ship bigger snapshots. CI includes a protocol test asserting serialized size budget.
- All numbers quantized at the protocol boundary to the precision the renderer needs (positions: 2 decimals).

## 8. Room Lifecycle

| Case | Policy |
|------|--------|
| Empty room TTL | 5 minutes after last human leaves → room deleted, invite code recycled |
| Room capacity | 4 seats total. Join beyond capacity → `roomFull` rejection |
| Host voluntary leave | Room closes immediately (`RoomClosed { hostLeft }`) if other players remain; if host is the last human, the empty-room TTL row applies |
| Match end | Host-only `endMatch` returns the room to lobby: spectators become players, ready states reset. (Client-side, the podium → lobby transition triggers this) |
| Reserved seat join | Joining with a playerId that holds a reserved (disconnected) seat → `AlreadyConnected`; the client must use `RejoinRoom` instead |
| Stale reserved seat | If grace expired without a `sweep` having run, the stale seat is resolved lazily at rejoin time: deterministic forfeit, same as swept removal |
| Invite code | 6-char uppercase alphanumeric (no 0/O/1/I). Collision → regenerate server-side. Codes recycle only after room deletion |
| Max concurrent rooms | Server config (default 200). Over limit → `ServerFull` |
| Round-in-progress join | `JoinRoom` mid-round succeeds only as **spectator for the current round**; joins play from next `ROUND_INTRO` (GDD § 7.10) |
| Server shutdown | Drain: no new rooms; existing rooms get `RoomClosed { reason: serverShutdown }` |

Rate-limit precision (§ 5.4): limits count **failed attempts too** (notFound/roomFull rejections consume budget); an attempt's budget expires exactly 60 s after it was counted. Because `shelf_web_socket` does not expose the remote IP, the per-IP limit degrades to **per-playerId identity** — accepted deviation, documented here.

Wire round model: the server is round-opaque (relay only). `RoomSnapshot.phase` reuses the domain `RoundPhase` vocabulary as an approximation — the authoritative round flow travels in `RoundStarting`/`RoundResultsMessage`/`RoomClosed`, not in room phase. `RoomSnapshot`'s `PlayerInfo` carries `connected` and `isSpectator` flags so clients can render reserved seats and spectators. The host ends a match over the wire with the client→server `EndMatch` message (host-only; server returns room to lobby per § 8 "Match end").

## 9. Netcode Anti-Patterns (bad → good)

**BAD — client-authoritative judging:**
```dart
// Non-host client:
if (myProgress >= finishX) send(Finished()); // ❌ client decides own win
```
**GOOD:** host detects the finish sensor contact, emits `PlayerFinished { tick, playerId }`, domain resolves placement.

**BAD — trusting client timestamps:**
```dart
if (now - msg.clientSentAt > timeout) drop(); // ❌ client clocks are lies
```
**GOOD:** server timestamps arrival; host tick numbers order the world.

**BAD — full world state every frame:** sending every obstacle's transform per snapshot. **GOOD:** snapshot = player states + dynamic bodies only; statics come from `minigameId + mapSeed`.

**BAD — stringly-typed protocol:**
```dart
socket.add('{"t":"move","x":$x}'); // ❌ hand-rolled JSON
```
**GOOD:** typed models in `shared/protocol` with roundtrip + rejection tests (testing doc § 5).

**BAD — fire-and-forget sends:**
```dart
socket.add(json); // ❌ no error handling on the sink
```
**GOOD:** send wrapper that catches sink errors, logs, and feeds the reconnect path (§ 5.3).

**BAD — silent catch anywhere in the network stack:**
```dart
try { msg = parse(data); } catch (_) {} // ❌
```
**GOOD:** catch `ProtocolException` → drop + log; anything else → log + escalate (connection is suspect).

---

Living spec. New edge case discovered → rule added here first, implementation follows (same commit).
