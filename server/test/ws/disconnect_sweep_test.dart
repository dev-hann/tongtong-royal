import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'ws_test_support.dart';

void main() {
  late ManualClock clock;
  late WsHarness harness;
  late TestClient host;
  late TestClient member;
  late String roomCode;

  setUp(() async {
    clock = ManualClock(startMs: 1000);
    harness = await startHarness(manager: RoomManager(clock: clock.call));
    host = await harness.connectAndHello('host', nickname: 'Host');
    final created =
        await (host..send(const CreateRoom())).next() as RoomSnapshot;
    roomCode = created.code;
    member = await harness.connectAndHello('member', nickname: 'Member');
    await (member..send(JoinRoom(code: roomCode))).next();
    await host.next(); // updated snapshot
  });

  tearDown(() async {
    await harness.close();
  });

  test('member socket close broadcasts an updated snapshot', () async {
    await member.close();
    final snapshot = await host.next() as RoomSnapshot;
    // Reserved grace seat stays listed as disconnected (network § 8).
    expect(snapshot.players, hasLength(2));
    final reserved = snapshot.players.singleWhere(
      (p) => p.playerId == 'member',
    );
    expect(reserved.connected, isFalse);
    expect(
      snapshot.players.singleWhere((p) => p.playerId == 'host').connected,
      isTrue,
    );
  });

  test('host grace expiry closes the room for everyone', () async {
    await host.close();
    final snapshot = await member.next() as RoomSnapshot;
    // Host went reserved: still listed, flagged disconnected.
    expect(snapshot.players, hasLength(2));
    expect(
      snapshot.players.singleWhere((p) => p.playerId == 'host').connected,
      isFalse,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    clock.advanceMs(graceWindowMs + 1);
    harness.server.sweep();

    expect(
      await member.next(),
      equals(const RoomClosed(reason: RoomCloseReason.hostLeft)),
    );
    await member.expectClosed();
  });

  test('host voluntary leave closes the room for the member', () async {
    host.send(const LeaveRoom());
    expect(
      await member.next(),
      equals(const RoomClosed(reason: RoomCloseReason.hostLeft)),
    );
    await member.expectClosed();
  });

  test('sweep past the empty-room TTL deletes an abandoned room', () async {
    final solo = await harness.connectAndHello('solo');
    solo.send(const CreateRoom());
    await solo.next(); // creation snapshot
    solo.send(const LeaveRoom()); // last human leaves; room lingers
    await solo.close();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(harness.server.roomCount, 2); // setUp room + solo room

    clock.advanceMs(emptyRoomTtlMs + 1);
    harness.server.sweep();
    expect(harness.server.roomCount, 1); // only the setUp room remains
  });
}
