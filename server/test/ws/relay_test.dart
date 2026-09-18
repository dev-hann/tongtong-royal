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

  test('relays member input to the host only', () async {
    final sample = input(7);
    member.send(sample);
    expect(await host.next(), equals(sample));
    await member.expectSilence();
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
