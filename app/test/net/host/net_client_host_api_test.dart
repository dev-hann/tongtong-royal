import 'package:app/infra/net_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import '../../infra/fake_connection.dart';

Future<NetClient> joinedClient(FakeConnection fake) async {
  final client = NetClient(
    connectionFactory: (_) async => fake,
    clock: () => Duration.zero,
    backoff: (_) async {},
  );
  await client.connect(Uri.parse('ws://test'), 'p1', 'nick');
  client.createRoom();
  fake.serverSends(
    encode(
      const RoomSnapshot(
        code: 'ABC234',
        players: [PlayerInfo(playerId: 'p1', nickname: 'nick', ready: true)],
        phase: RoundPhase.lobby,
        roundIndex: 0,
      ),
    ),
  );
  await pumpEventQueue();
  return client;
}

void main() {
  group('NetClient.host api (additive)', () {
    test('sendHost puts a typed host message on the wire when joined',
        () async {
      final fake = FakeConnection();
      final client = await joinedClient(fake);
      addTearDown(client.dispose);

      const message = RoundStarting(
        roundIndex: 2,
        minigameId: 'trap_race',
        mapSeed: 42,
        timeoutMs: 90_000,
      );
      client.sendHost(message);

      expect(fake.sent.last, encode(message));
      expect(decode(fake.sent.last), message);
    });

    test('sendHost is a logged no-op before joining a room', () async {
      final fake = FakeConnection();
      final client = NetClient(
        connectionFactory: (_) async => fake,
        clock: () => Duration.zero,
        backoff: (_) async {},
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://test'), 'p1', 'nick');

      client.sendHost(const RoundStarting(
        roundIndex: 0,
        minigameId: 'trap_race',
        mapSeed: 1,
        timeoutMs: 90_000,
      ));
      await pumpEventQueue();

      expect(
        fake.sent,
        isNot(contains(encode(const RoundStarting(
          roundIndex: 0,
          minigameId: 'trap_race',
          mapSeed: 1,
          timeoutMs: 90_000,
        )))),
      );
    });

    test('memberInputs fans out relayed input samples', () async {
      final fake = FakeConnection();
      final client = await joinedClient(fake);
      addTearDown(client.dispose);
      final received = <PlayerInputMessage>[];
      client.memberInputs.listen(received.add);

      fake.serverSends(
        encode(PlayerInputMessage(
          seq: 7,
          moveX: 0.5,
          moveY: -0.25,
          jump: true,
          dash: false,
        )),
      );
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.seq, 7);
      expect(received.single.moveX, 0.5);
      expect(received.single.moveY, -0.25);
      expect(received.single.jump, isTrue);
    });

    test('memberInputs stays silent for non-input traffic', () async {
      final fake = FakeConnection();
      final client = await joinedClient(fake);
      addTearDown(client.dispose);
      final received = <PlayerInputMessage>[];
      client.memberInputs.listen(received.add);

      fake
        ..serverSends(encode(const Pong()))
        ..serverSends('{"t":"hax","v":{}}');
      await pumpEventQueue();

      expect(received, isEmpty);
    });
  });
}
