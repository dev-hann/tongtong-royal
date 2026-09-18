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

  test('reserved disconnected seat is listed with connected:false', () async {
    final guest = await harness.connectAndHello('guest', nickname: 'Guest');
    await (guest..send(JoinRoom(code: roomCode))).next();
    await host.next(); // both seated

    await guest.close();
    final snapshot = await host.next() as RoomSnapshot;
    final seat = snapshot.players.singleWhere((p) => p.playerId == 'guest');
    expect(
      seat.connected,
      isFalse,
      reason: 'reserved grace seats must be listed as disconnected',
    );
    expect(
      snapshot.players,
      hasLength(2),
      reason: 'reserved seat stays visible during grace',
    );
  });

  test('mid-match joiner is listed with isSpectator:true', () async {
    final guest = await harness.connectAndHello('guest', nickname: 'Guest');
    await (guest..send(JoinRoom(code: roomCode))).next();
    await host.next(); // both seated

    host.send(const SetReady(ready: true));
    guest.send(const SetReady(ready: true));
    await host.next(); // host ready
    await guest.next(); // guest ready
    await host.next(); // guest ready to host
    await guest.next(); // host ready to guest
    host.send(const StartMatch());
    await host.next();
    await guest.next();

    final lateJoiner = await harness.connectAndHello('late', nickname: 'Late');
    lateJoiner.send(JoinRoom(code: roomCode));
    final view = await lateJoiner.next() as RoomSnapshot;
    final seat = view.players.singleWhere((p) => p.playerId == 'late');
    expect(seat.isSpectator, isTrue);
    final playerSeat = view.players.singleWhere((p) => p.playerId == 'host');
    expect(playerSeat.isSpectator, isFalse);
    expect(playerSeat.connected, isTrue);
  });

  test('after EndMatch spectators become players', () async {
    final guest = await harness.connectAndHello('guest', nickname: 'Guest');
    await (guest..send(JoinRoom(code: roomCode))).next();
    await host.next(); // both seated

    host.send(const SetReady(ready: true));
    guest.send(const SetReady(ready: true));
    await host.next();
    await guest.next();
    await host.next();
    await guest.next();
    host.send(const StartMatch());
    await host.next();
    await guest.next();

    final lateJoiner = await harness.connectAndHello('late', nickname: 'Late');
    lateJoiner.send(JoinRoom(code: roomCode));
    await lateJoiner.next(); // spectator snapshot
    await host.next(); // spectator snapshot to host
    await guest.next();

    host.send(const EndMatch());
    final view = await lateJoiner.next() as RoomSnapshot;
    expect(view.phase, RoundPhase.lobby);
    final seat = view.players.singleWhere((p) => p.playerId == 'late');
    expect(
      seat.isSpectator,
      isFalse,
      reason: 'network doc § 8: spectators become players at match end',
    );
  });
}
