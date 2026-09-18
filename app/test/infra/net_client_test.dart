import 'package:app/infra/connection.dart';
import 'package:app/infra/net_client.dart';
import 'package:app/infra/net_log.dart';
import 'package:app/infra/net_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'fake_connection.dart';

/// Factory scripting: each connection request consumes one outcome
/// (a [FakeConnection] to hand out, or any [Object] to fail with).
final class FakeFactory {
  final List<Object> _outcomes = <Object>[];

  int calls = 0;

  void nextIs(FakeConnection connection) => _outcomes.add(connection);

  void nextFails(Object error) => _outcomes.add(error);

  Future<Connection> call(Uri uri) {
    calls++;
    if (_outcomes.isEmpty) {
      return Future<Connection>.error(
        StateError('no scripted outcome for connection #$calls'),
      );
    }
    final outcome = _outcomes.removeAt(0);
    if (outcome is FakeConnection) {
      return Future<Connection>.value(outcome);
    }
    return Future<Connection>.error(outcome);
  }
}

final class MemoryLog implements NetLog {
  final List<String> infos = <String>[];
  final List<String> warns = <String>[];
  final List<String> errors = <String>[];

  @override
  void info(String message) => infos.add(message);

  @override
  void warn(String message) => warns.add(message);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      errors.add(message);
}

/// Per-test wiring: scripted factory, fake clock, recording backoff.
final class Harness {
  Harness() {
    client = NetClient(
      connectionFactory: factory.call,
      clock: () => now,
      backoff: (int attempt) {
        backoffCalls.add(attempt);
        return Future<void>.value();
      },
      log: log,
    );
  }

  final FakeFactory factory = FakeFactory();
  final MemoryLog log = MemoryLog();
  final List<int> backoffCalls = <int>[];
  Duration now = Duration.zero;
  late NetClient client;

  Future<void> connect({FakeConnection? connection}) async {
    final fake = connection ?? FakeConnection();
    factory.nextIs(fake);
    await client.connect(Uri.parse('ws://test'), 'p1', 'nick');
  }

  /// Joins `ABC234` on [connection] and returns it once joined.
  Future<FakeConnection> joinRoom({
    FakeConnection? connection,
  }) async {
    final fake = connection ?? FakeConnection();
    await connect(connection: fake);
    client.createRoom();
    fake.serverSends(encode(roomSnapshot()));
    await pumpEventQueue();
    return fake;
  }

  void elapse(Duration d) => now += d;
}

RoomSnapshot roomSnapshot({
  String code = 'ABC234',
  RoundPhase phase = RoundPhase.lobby,
}) =>
    RoomSnapshot(
      code: code,
      players: const [
        PlayerInfo(playerId: 'p1', nickname: 'nick', ready: true),
      ],
      phase: phase,
      roundIndex: 0,
    );

Snapshot gameSnapshot(int tick) => Snapshot(
      tick: tick,
      players: const [
        PlayerState(playerId: 'p1', x: 1, y: 2, angle: 0, vx: 0, vy: 0),
      ],
    );

const RoundStarting roundStartingMsg = RoundStarting(
  roundIndex: 0,
  minigameId: 'race',
  mapSeed: 7,
  timeoutMs: 60000,
);

const RoundResultsMessage resultsMsg = RoundResultsMessage(
  roundResult: RoundResult(
    roundIndex: 0,
    minigameId: 'race',
    placements: [Placement(playerId: 'p1', rank: 1, points: 3)],
  ),
);

void main() {
  group('handshake', () {
    test('connect sends Hello with protocol version and identity',
        () async {
      final h = Harness();
      final fake = FakeConnection();
      h.factory.nextIs(fake);

      await h.client.connect(Uri.parse('ws://test'), 'p1', 'nick');

      expect(h.client.state, const NetConnected());
      expect(fake.sent, hasLength(1));
      expect(
        decode(fake.sent.single),
        const Hello(
          protocolVersion: protocolVersion,
          playerId: 'p1',
          nickname: 'nick',
        ),
      );
    });

    test('version mismatch is terminal and never retried', () async {
      final h = Harness();
      final fake = FakeConnection();
      h.factory.nextIs(fake);
      await h.connect(connection: fake);

      fake.serverSends(
        encode(const VersionMismatch(status: VersionStatus.clientTooOld)),
      );
      await pumpEventQueue();

      expect(
        h.client.state,
        const NetVersionMismatch(status: VersionStatus.clientTooOld),
      );
      expect(h.factory.calls, 1);
      expect(h.backoffCalls, isEmpty);
    });
  });

  group('rooms', () {
    test('createRoom sends CreateRoom and joins on RoomSnapshot',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      expect(decode(fake.sent[1]), const CreateRoom());
      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
      expect(h.client.lastRoomCode, 'ABC234');
    });

    test('joinRoom sends JoinRoom and joins on RoomSnapshot', () async {
      final h = Harness();
      final fake = FakeConnection();
      h.factory.nextIs(fake);
      await h.client.connect(Uri.parse('ws://test'), 'p1', 'nick');

      h.client.joinRoom('XYZ789');
      fake.serverSends(encode(roomSnapshot(code: 'XYZ789')));
      await pumpEventQueue();

      expect(decode(fake.sent[1]), const JoinRoom(code: 'XYZ789'));
      expect(h.client.state, const NetJoined(roomCode: 'XYZ789'));
    });

    test('rejoinRoom sends RejoinRoom', () async {
      final h = Harness();
      final fake = FakeConnection();
      h.factory.nextIs(fake);
      await h.client.connect(Uri.parse('ws://test'), 'p1', 'nick');

      h.client.rejoinRoom('ABC234');
      await pumpEventQueue();

      expect(decode(fake.sent[1]), const RejoinRoom(code: 'ABC234'));
    });

    test('setReady, startMatch and ping send expected messages',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      h.client.setReady(true);
      h.client.startMatch();
      h.client.ping();

      expect(decode(fake.sent[2]), const SetReady(ready: true));
      expect(decode(fake.sent[3]), const StartMatch());
      expect(decode(fake.sent[4]), const Ping());
    });

    test('pong updates status ping using the injected clock', () async {
      final h = Harness();
      final fake = await h.joinRoom();

      h.client.ping();
      h.elapse(const Duration(milliseconds: 150));
      fake.serverSends(encode(const Pong()));
      await pumpEventQueue();

      expect(h.client.status.ping, const Duration(milliseconds: 150));
    });
  });

  group('input', () {
    test('seq increments monotonically per connection', () async {
      final h = Harness();
      final fake = await h.joinRoom();

      h.client.sendInput(PlayerInputState());
      h.client.sendInput(PlayerInputState(jumpPressed: true));

      final first = decode(fake.sent[2]) as PlayerInputMessage;
      final second = decode(fake.sent[3]) as PlayerInputMessage;
      expect(first.seq, 1);
      expect(second.seq, 2);
      expect(h.client.lastInputSeq, 2);
    });

    test('NaN and out-of-range values are sanitized on the wire',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      h.client.sendInput(
        PlayerInputState(moveDir: Vector2(double.nan, 3)),
      );
      h.client.sendInput(PlayerInputState(moveDir: Vector2(1.5, -2)));
      await pumpEventQueue();

      final nanMsg = decode(fake.sent[2]) as PlayerInputMessage;
      expect(nanMsg.moveX, 0);
      expect(nanMsg.moveY, 0);
      final clampedMsg = decode(fake.sent[3]) as PlayerInputMessage;
      expect(clampedMsg.moveX, 1);
      expect(clampedMsg.moveY, -1);
    });

    test('sendInput outside a room is a logged no-op', () async {
      final h = Harness();
      final fake = FakeConnection();
      h.factory.nextIs(fake);
      await h.client.connect(Uri.parse('ws://test'), 'p1', 'nick');

      h.client.sendInput(PlayerInputState(jumpPressed: true));

      expect(fake.sent, hasLength(1)); // only the Hello
      expect(h.log.warns, isNotEmpty);
    });
  });

  group('fan-out', () {
    test('snapshots stream receives decoded room snapshots', () async {
      final h = Harness();
      final received = <RoomSnapshot>[];
      h.client.snapshots.listen(received.add);
      final fake = await h.joinRoom();

      fake.serverSends(encode(roomSnapshot()));
      await pumpEventQueue();

      expect(received, hasLength(2));
      expect(received.last.code, 'ABC234');
    });

    test('game snapshots fan out and stale ticks are dropped', () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final received = <Snapshot>[];
      h.client.gameSnapshots.listen(received.add);

      fake
        ..serverSends(encode(gameSnapshot(5)))
        ..serverSends(encode(gameSnapshot(5)))
        ..serverSends(encode(gameSnapshot(4)))
        ..serverSends(encode(gameSnapshot(6)));
      await pumpEventQueue();

      expect(received.map((s) => s.tick), [5, 6]);
    });

    test('roundStarting and results fan out on their streams', () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final rounds = <RoundStarting>[];
      final results = <RoundResultsMessage>[];
      h.client.roundStarting.listen(rounds.add);
      h.client.results.listen(results.add);

      fake
        ..serverSends(encode(roundStartingMsg))
        ..serverSends(encode(resultsMsg));
      await pumpEventQueue();

      expect(rounds, [roundStartingMsg]);
      expect(results, [resultsMsg]);
    });

    test('roomClosed fans out with the reason and closes', () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final closed = <RoomClosed>[];
      h.client.roomClosed.listen(closed.add);

      fake.serverSends(
        encode(const RoomClosed(reason: RoomCloseReason.hostLeft)),
      );
      await pumpEventQueue();

      expect(closed.single.reason, RoomCloseReason.hostLeft);
      expect(
        h.client.state,
        const NetClosed(
          needsManualRejoin: false,
          roomCloseReason: RoomCloseReason.hostLeft,
        ),
      );
    });

    test('malformed JSON is dropped and logged without throwing',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      fake.serverSends('this is not json');
      await pumpEventQueue();

      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
      expect(h.log.warns, isNotEmpty);
    });

    test('unknown tag is dropped and logged', () async {
      final h = Harness();
      final fake = await h.joinRoom();

      fake.serverSends('{"t":"hax","v":{}}');
      await pumpEventQueue();

      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
      expect(h.log.warns, isNotEmpty);
    });

    test('client-to-server tags arriving from the server are dropped',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      fake.serverSends(
        encode(const Hello(
          protocolVersion: protocolVersion,
          playerId: 'p2',
          nickname: 'ghost',
        )),
      );
      await pumpEventQueue();

      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
      expect(h.log.warns, isNotEmpty);
    });

    test('server notices surface on the notices stream', () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final received = <WireMessage>[];
      h.client.notices.listen(received.add);

      fake.serverSends(encode(const RateLimited()));
      await pumpEventQueue();

      expect(received.single, isA<RateLimited>());
    });
  });

  group('app lifecycle (network doc 5.3)', () {
    test('pause closes the connection cleanly and arms reconnect',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();

      h.client.onAppLifecyclePaused();

      expect(fake.closed, isTrue);
      expect(
        h.client.state,
        const NetReconnecting(roomCode: 'ABC234', attempt: 0),
      );
      expect(h.backoffCalls, isEmpty); // waits for resume, no spam
    });

    test('resume within grace auto-rejoins without user interaction',
        () async {
      final h = Harness();
      await h.joinRoom();

      h.client.onAppLifecyclePaused();
      h.elapse(const Duration(seconds: 3));
      final fake2 = FakeConnection();
      h.factory.nextIs(fake2);
      await h.client.onAppLifecycleResumed();

      expect(decode(fake2.sent[0]).runtimeType, Hello);
      expect(decode(fake2.sent[1]), const RejoinRoom(code: 'ABC234'));

      fake2.serverSends(encode(roomSnapshot()));
      await pumpEventQueue();

      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
    });

    test('resume after grace closes with needsManualRejoin', () async {
      final h = Harness();
      await h.joinRoom();

      h.client.onAppLifecyclePaused();
      h.elapse(rejoinGraceWindow + const Duration(seconds: 1));
      await h.client.onAppLifecycleResumed();

      expect(
        h.client.state,
        const NetClosed(needsManualRejoin: true),
      );
      expect(h.factory.calls, 1); // no second connection attempt
    });
  });

  group('snapshot starvation watchdog (network doc 6)', () {
    test('no game snapshot for 2 s during a match marks unstable',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final statuses = <NetStatus>[];
      h.client.statusChanges.listen(statuses.add);

      fake
        ..serverSends(encode(roundStartingMsg))
        ..serverSends(encode(gameSnapshot(1)));
      await pumpEventQueue();
      expect(h.client.status.unstable, isFalse);

      h
        ..elapse(snapshotStarvationTimeout)
        ..client.onWatchdogTick();
      await pumpEventQueue();

      expect(h.client.status.unstable, isTrue);
      expect(statuses.last.unstable, isTrue);
    });

    test('the next snapshot clears the unstable flag', () async {
      final h = Harness();
      final fake = await h.joinRoom();

      fake
        ..serverSends(encode(roundStartingMsg))
        ..serverSends(encode(gameSnapshot(1)));
      await pumpEventQueue();

      h
        ..elapse(snapshotStarvationTimeout)
        ..client.onWatchdogTick();
      expect(h.client.status.unstable, isTrue);

      fake.serverSends(encode(gameSnapshot(2)));
      await pumpEventQueue();

      expect(h.client.status.unstable, isFalse);
    });

    test('watchdog ignores starvation outside an active match', () async {
      final h = Harness();
      await h.joinRoom(); // lobby phase, no match running

      h.elapse(const Duration(seconds: 10));
      h.client.onWatchdogTick();

      expect(h.client.status.unstable, isFalse);
    });
  });

  group('reconnect (network doc 5)', () {
    test('server close while joined triggers backoff reconnect and '
        'rejoin succeeds', () async {
      final h = Harness();
      final fake1 = await h.joinRoom();

      final fake2 = FakeConnection();
      h.factory.nextIs(fake2);
      fake1.serverCloses();
      await pumpEventQueue();

      expect(
        h.client.state,
        const NetReconnecting(roomCode: 'ABC234', attempt: 1),
      );
      expect(h.backoffCalls, [1]);
      expect(decode(fake2.sent[0]).runtimeType, Hello);
      expect(decode(fake2.sent[1]), const RejoinRoom(code: 'ABC234'));

      fake2.serverSends(encode(roomSnapshot()));
      await pumpEventQueue();

      expect(h.client.state, const NetJoined(roomCode: 'ABC234'));
    });

    test('exhausted attempts close with needsManualRejoin', () async {
      final h = Harness();
      final fake1 = await h.joinRoom();

      for (var i = 0; i < maxReconnectAttempts; i++) {
        h.factory.nextFails(StateError('socket refused'));
      }
      fake1.serverCloses();
      await pumpEventQueue();

      expect(
        h.client.state,
        const NetClosed(needsManualRejoin: true),
      );
      expect(h.backoffCalls, [1, 2, 3, 4, 5]);
      expect(h.factory.calls, maxReconnectAttempts + 1);
    });

    test('sink error during send is caught and drops the connection',
        () async {
      final h = Harness();
      final fake = await h.joinRoom();
      final statuses = <NetStatus>[];
      h.client.statusChanges.listen(statuses.add);

      fake.failNextSend = StateError('sink exploded');
      h.client.sendInput(PlayerInputState());
      await pumpEventQueue();

      expect(h.log.errors, isNotEmpty);
      expect(statuses.any((s) => s.state is NetDisconnected), isTrue);
      expect(h.client.status.lastError, isNotNull);
    });
  });

  group('user close', () {
    test('close is terminal and does not reconnect', () async {
      final h = Harness();
      await h.joinRoom();

      await h.client.close();
      await pumpEventQueue();

      expect(
        h.client.state,
        const NetClosed(needsManualRejoin: false),
      );
      expect(h.backoffCalls, isEmpty);
    });
  });
}
