/// E2E integration test (testing doc § 7): create room → join →
/// ready → 1 short round (relay contract) → results → podium → back
/// to lobby, against the real in-process `GameServer` over loopback
/// WebSockets.
///
/// Placement note: the DoD's "fake clients" wording predates the
/// current workspace split — `app` (NetClient) and `server`
/// (GameServer) do not depend on each other and no pubspec edits were
/// allowed, so a cross-package client-level E2E is not expressible
/// today (documented gap in the task report). This test proves the
/// server + protocol + host-relay contract at the wire level with raw
/// WebSocket clients; the app-side NetClient behavior is covered by
/// `app/test/infra/net_client_test.dart` over a fake connection.
///
/// The host role is driven by script (typed sends at wire-cadence),
/// not by `HostRuntime`: the app package cannot be imported here.
/// Judging stays in the domain — placements are produced by the real
/// `TrapRace.resolve` (AGENTS § 6.3).
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'e2e_support.dart';

/// 20 Hz host snapshot cadence (network doc § 1).
const Duration snapshotCadence = Duration(milliseconds: 50);

/// Number of snapshots in the simulated ~1 s round.
const int snapshotCount = 20;

/// 60 Hz simulation, snapshot every 3rd tick (network doc § 1).
const int ticksPerSnapshot = 3;

void main() {
  group('E2E match flow', () {
    late E2eHarness harness;
    late E2eClient host;
    late E2eClient guest;

    setUp(() async {
      harness = await startE2e();
      host = await harness.connect('host-id', 'Host');
      guest = await harness.connect('guest-id', 'Guest');
    });

    tearDown(() async {
      await host.close();
      await guest.close();
      await harness.close();
    });

    test('create → join → ready → round → results → podium → lobby',
        () async {
      // --- Lobby: create + join via received code (§ 2 handshake is
      // implicit accept; the RoomSnapshot proves liveness).
      host.send(const CreateRoom());
      final created = await host.waitFor<RoomSnapshot>(
        (s) => s.players.length == 1,
        because: 'create room reply',
      );
      final code = created.code;
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')),
          reason: '6-char code, no 0/O/1/I (network doc § 8)');

      guest.send(JoinRoom(code: code));
      final hostView = await host.waitFor<RoomSnapshot>(
        (s) => s.players.length == 2,
        because: 'join broadcast to host',
      );
      final guestView = await guest.waitFor<RoomSnapshot>(
        (s) => s.players.length == 2,
        because: 'join reply to guest',
      );
      for (final snapshot in [hostView, guestView]) {
        expect(snapshot.code, code);
        expect(snapshot.phase, RoundPhase.lobby);
        expect(
          snapshot.players.map((p) => p.playerId).toSet(),
          {'host-id', 'guest-id'},
        );
        expect(snapshot.players.every((p) => p.connected && !p.isSpectator),
            isTrue,
            reason: 'both seats live players (network doc § 8)');
      }

      // --- Ready: both flag up, snapshots reflect it.
      host.send(const SetReady(ready: true));
      await host.waitFor<RoomSnapshot>(
        (s) => s.players.any((p) => p.playerId == 'host-id' && p.ready),
        because: 'host ready broadcast',
      );
      guest.send(const SetReady(ready: true));
      await host.waitFor<RoomSnapshot>(
        (s) => s.players.length == 2 && s.players.every((p) => p.ready),
        because: 'guest ready broadcast to host',
      );
      await guest.waitFor<RoomSnapshot>(
        (s) => s.players.length == 2 && s.players.every((p) => p.ready),
        because: 'guest ready echo',
      );

      // --- Match start (host-only, network doc § 6): both clients
      // see the in-match snapshot.
      host.send(const StartMatch());
      await host.waitFor<RoomSnapshot>(
        (s) => s.phase == RoundPhase.roundPlay,
        because: 'match start snapshot to host',
      );
      final guestInMatch = await guest.waitFor<RoomSnapshot>(
        (s) => s.phase == RoundPhase.roundPlay,
        because: 'match start snapshot to guest',
      );
      expect(guestInMatch.roundIndex, 0);

      // --- Round intro: host broadcasts RoundStarting (§ 4 seeding).
      const roundStarting = RoundStarting(
        roundIndex: 0,
        minigameId: 'trap_race',
        mapSeed: 7,
        timeoutMs: 1000,
      );
      host.send(roundStarting);
      final guestRound = await guest.waitFor<RoundStarting>(
        (m) => true,
        because: 'round announcement relay',
      );
      expect(guestRound, roundStarting);

      // --- Round body: host broadcasts snapshots at 20 Hz for ~1 s
      // (scripted positions; wire contract only, network doc § 1).
      var adversarialInjected = false;
      for (var i = 1; i <= snapshotCount; i++) {
        host.send(
          Snapshot(
            tick: i * ticksPerSnapshot,
            players: [
              PlayerState(
                playerId: 'host-id',
                x: 0.5 * i,
                y: 1,
                angle: 0,
                vx: 1,
                vy: 0,
              ),
              PlayerState(
                playerId: 'guest-id',
                // 4-decimal input proves 2-decimal quantization on the
                // wire (network doc § 7).
                x: 1.2345 + i,
                y: 1,
                angle: 0,
                vx: 1,
                vy: 0,
              ),
            ],
          ),
        );
        if (i == 5 && !adversarialInjected) {
          adversarialInjected = true;
          // Adversarial mid-flow (§ 6): malformed JSON must be dropped
          // without killing the connection.
          guest.sendRaw('{"t":"input","v":{"seq":1,');
        }
        await Future<void>.delayed(snapshotCadence);
      }

      // Guest received the whole snapshot stream despite the garbage
      // frame — the connection survived (§ 6).
      final lastSnapshot = await guest.waitFor<Snapshot>(
        (s) => s.tick == snapshotCount * ticksPerSnapshot,
        because: 'snapshot stream survived malformed frame',
      );
      expect(guest.receivedOf<Snapshot>().length, snapshotCount,
          reason: 'every host snapshot relayed');
      final quantized =
          lastSnapshot.players.firstWhere((p) => p.playerId == 'guest-id');
      expect(quantized.x, PlayerState.quantize(1.2345 + snapshotCount),
          reason: 'positions quantized to 2 decimals (network doc § 7)');

      // --- Inputs: guest uploads 10 samples with a forged identity;
      // the server must stamp the true connection identity (§ 1).
      for (var seq = 1; seq <= 10; seq++) {
        guest.send(
          PlayerInputMessage(
            seq: seq,
            moveX: 1,
            moveY: 0,
            jump: seq == 3,
            dash: false,
            playerId: 'impostor-id',
          ),
        );
      }
      await host.waitFor<PlayerInputMessage>(
        (m) => m.seq == 10,
        because: 'all guest inputs relayed to host',
      );
      final relayedInputs = host.receivedOf<PlayerInputMessage>();
      expect(relayedInputs, hasLength(10));
      expect(
        relayedInputs.every((m) => m.playerId == 'guest-id'),
        isTrue,
        reason: 'server stamps sending connection (network doc § 1)',
      );
      expect(
        relayedInputs.any((m) => m.playerId == 'impostor-id'),
        isFalse,
        reason: 'client-supplied identity never trusted',
      );

      // Host input is consumed locally, never relayed (§ 1).
      host.send(
        PlayerInputMessage(seq: 1, moveX: 1, moveY: 0, jump: false, dash: true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(guest.receivedOf<PlayerInputMessage>(), isEmpty,
          reason: 'host input not relayed to members');

      // --- Results: host judges via the domain rules and broadcasts.
      final result = const TrapRace().resolve(
        const RoundEvents(
          roundIndex: 0,
          events: [
            PlayerFinished(tick: 120, playerId: 'host-id'),
            PlayerFinished(tick: 200, playerId: 'guest-id'),
          ],
        ),
        const TrapRaceInput(roster: {'host-id', 'guest-id'}),
      );
      host.send(RoundResultsMessage(roundResult: result));
      final guestResult = await guest.waitFor<RoundResultsMessage>(
        (m) => true,
        because: 'round results relayed to guest',
      );
      expect(guestResult.roundResult.roundIndex, 0);
      expect(guestResult.roundResult.minigameId, 'trap_race');
      expect(guestResult.roundResult.placements, [
        const Placement(playerId: 'host-id', rank: 1, points: 2),
        const Placement(playerId: 'guest-id', rank: 2, points: 1),
      ]);

      // --- Podium: final standings derived from the wire-delivered
      // result by the domain (GDD § 2.1). The podium screen consumes
      // exactly this projection.
      final match = Rankings.finalRanking(
        [guestResult.roundResult],
        const {},
      );
      expect(match.finalRankings, hasLength(2));
      expect(match.finalRankings.first.playerId, 'host-id');
      expect(match.finalRankings.first.rank, 1);
      expect(match.finalRankings.first.points, 2);
      expect(match.finalRankings.last.playerId, 'guest-id');
      expect(match.finalRankings.last.points, 1);

      // --- Match end (host-only, network doc § 8): room back to
      // lobby, ready flags reset.
      host.send(const EndMatch());
      bool backInLobby(RoomSnapshot s) =>
          s.players.length == 2 &&
          s.phase == RoundPhase.lobby &&
          s.players.every((p) => !p.ready);
      final hostLobby = await host.waitFor<RoomSnapshot>(
        backInLobby,
        because: 'end match snapshot to host',
      );
      final guestLobby = await guest.waitFor<RoomSnapshot>(
        backInLobby,
        because: 'end match snapshot to guest',
      );
      for (final snapshot in [hostLobby, guestLobby]) {
        expect(snapshot.players, hasLength(2));
        expect(snapshot.players.every((p) => !p.ready), isTrue,
            reason: 'ready states reset after match (network doc § 8)');
      }

      // --- Server dropped the malformed frame loudly (§ 6: drop +
      // log, never crash) and the sockets stayed open throughout.
      expect(
        harness.logLines.any((line) => line.contains('dropping invalid')),
        isTrue,
        reason: 'malformed frame logged',
      );

      // --- Relay semantics: the host never receives its own
      // broadcasts (server excludes the sender).
      expect(host.receivedOf<Snapshot>(), isEmpty);
      expect(host.receivedOf<RoundStarting>(), isEmpty);
      expect(host.receivedOf<RoundResultsMessage>(), isEmpty);
    });
  });
}
