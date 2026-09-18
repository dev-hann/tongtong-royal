import 'dart:async' show TimeoutException;

import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'ws_test_support.dart';

void main() {
  late WsHarness harness;
  late TestClient host;
  late TestClient member;
  late String roomCode;

  setUp(() async {
    harness = await startHarness();
    host = await harness.connectAndHello('host');
    final created =
        await (host..send(const CreateRoom())).next() as RoomSnapshot;
    roomCode = created.code;
    member = await harness.connectAndHello('member');
    await (member..send(JoinRoom(code: roomCode))).next();
    await host.next(); // updated snapshot
  });

  tearDown(() async {
    await harness.close();
  });

  PlayerInputMessage input(int seq) => PlayerInputMessage(
    seq: seq,
    moveX: 0.5,
    moveY: -0.5,
    jump: false,
    dash: false,
  );

  test('relays member input to the host stamped with the sender id', () async {
    member.send(input(7));
    final relayed = await host.next() as PlayerInputMessage;
    expect(relayed.seq, 7);
    expect(relayed.moveX, 0.5);
    expect(relayed.moveY, -0.5);
    expect(relayed.playerId, 'member',
        reason: 'network doc § 1: server stamps the sending connection');
    await member.expectSilence();
  });

  test('overwrites a client-supplied playerId, never trusting it', () async {
    member.send(
      PlayerInputMessage(
        seq: 1,
        moveX: 0.5,
        moveY: -0.5,
        jump: false,
        dash: false,
        playerId: 'someone-else',
      ),
    );
    final relayed = await host.next() as PlayerInputMessage;
    expect(relayed.playerId, 'member',
        reason: 'trust model § 3: connection registry is the source of truth');
  });

  test('interleaved members keep per-connection attribution', () async {
    final memberB = await harness.connectAndHello('memberB');
    await (memberB..send(JoinRoom(code: roomCode))).next();
    await host.next(); // updated snapshot for B's join

    memberB.send(input(1));
    member.send(input(2));
    final first = await host.next() as PlayerInputMessage;
    final second = await host.next() as PlayerInputMessage;

    expect({first.playerId, second.playerId}, {'member', 'memberB'});
    // Order within a burst is per-connection only; ids pair with seqs.
    expect(
      {
        '${first.playerId}:${first.seq}',
        '${second.playerId}:${second.seq}',
      },
      {'member:2', 'memberB:1'},
    );
  });

  test('drops input from a connection that is in no room', () async {
    final outsider = await harness.connectAndHello('outsider');
    outsider.send(input(1));
    await host.expectSilence();
    await member.expectSilence();
  });

  test('rate-caps input floods at 120 messages per second', () async {
    const sent = 200;
    for (var seq = 0; seq < sent; seq++) {
      member.send(input(seq));
    }
    var relayed = 0;
    while (true) {
      try {
        final frame = await host.frames.nextFrame(quietWindow);
        if (frame == null) {
          break;
        }
        if (decode(frame) is PlayerInputMessage) {
          relayed++;
        }
      } on TimeoutException {
        break;
      }
    }
    expect(relayed, lessThan(sent));
    expect(relayed, greaterThanOrEqualTo(1));
    expect(relayed, lessThanOrEqualTo(120));
  });

  test('relays host snapshots to members but not back to the host', () async {
    const snapshot = Snapshot(
      tick: 42,
      players: [
        PlayerState(playerId: 'host', x: 1.25, y: 0, angle: 0, vx: 0, vy: 0),
      ],
    );
    host.send(snapshot);
    expect(await member.next(), equals(snapshot));
    await host.expectSilence();

    member.send(snapshot);
    await member.expectSilence();
    await host.expectSilence();
  });

  test('relays host round events to members', () async {
    const roundStarting = RoundStarting(
      roundIndex: 0,
      minigameId: 'sumo',
      mapSeed: 99,
      timeoutMs: 30000,
    );
    host.send(roundStarting);
    expect(await member.next(), equals(roundStarting));
  });
}
