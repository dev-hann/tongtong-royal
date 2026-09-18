import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'ws_test_support.dart';

void main() {
  late WsHarness harness;
  late TestClient host;
  late String roomCode;

  setUp(() async {
    harness = await startHarness();
    host = await harness.connectAndHello('host', nickname: 'Host');
    final created =
        await (host..send(const CreateRoom())).next() as RoomSnapshot;
    roomCode = created.code;
  });

  tearDown(() async {
    await harness.close();
  });

  group('JoinRoom', () {
    test('unknown code receives JoinFailed{notFound}', () async {
      final client = await harness.connectAndHello('lost');
      client.send(const JoinRoom(code: 'ZZZZZZ'));
      final reply = await client.next();
      expect(reply, const JoinFailed(reason: JoinFailReason.notFound));
    });

    test('full room receives JoinFailed{roomFull}', () async {
      final seats = <TestClient>[];
      for (var i = 0; i < 3; i++) {
        final guest = await harness.connectAndHello('guest$i');
        await (guest..send(JoinRoom(code: roomCode))).next();
        seats.add(guest);
      }
      await host.next(); // membership updates
      await host.next();
      await host.next();

      final overflow = await harness.connectAndHello('fifth');
      overflow.send(JoinRoom(code: roomCode));
      final reply = await overflow.next();
      expect(reply, const JoinFailed(reason: JoinFailReason.roomFull));
    });

    test('connection survives a JoinFailed rejection', () async {
      final client = await harness.connectAndHello('retry');
      client.send(const JoinRoom(code: 'ZZZZZZ'));
      await client.next(); // JoinFailed

      client.send(const CreateRoom());
      final snapshot = await client.next();
      expect(snapshot, isA<RoomSnapshot>());
      expect(snapshot, isNot(isA<JoinFailed>()));
    });
  });

  group('RejoinRoom', () {
    test('unknown code receives JoinFailed{notFound}', () async {
      final client = await harness.connectAndHello('reloser');
      client.send(const RejoinRoom(code: 'ZZZZZZ'));
      final reply = await client.next();
      expect(reply, const JoinFailed(reason: JoinFailReason.notFound));
    });
  });
}
