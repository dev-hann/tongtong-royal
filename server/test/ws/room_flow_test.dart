import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'ws_test_support.dart';

void main() {
  late WsHarness harness;
  late TestClient host;
  late TestClient guest;
  late String roomCode;

  setUp(() async {
    harness = await startHarness();
    host = await harness.connectAndHello('host', nickname: 'Host');
    final created =
        await (host..send(const CreateRoom())).next() as RoomSnapshot;
    roomCode = created.code;
    guest = await harness.connectAndHello('guest', nickname: 'Guest');
    await (guest..send(JoinRoom(code: roomCode))).next();
    await host.next(); // host's updated snapshot
  });

  tearDown(() async {
    await harness.close();
  });

  test('create then join broadcasts snapshots with both players', () async {
    final guestView = await harness.connectAndHello('late');
    guestView.send(JoinRoom(code: roomCode));
    final snapshot = await guestView.next() as RoomSnapshot;
    expect(snapshot.code, roomCode);
    expect(snapshot.phase, RoundPhase.lobby);
    expect(snapshot.players, hasLength(3));
    expect(
      snapshot.players.map((p) => p.playerId),
      containsAll(<String>['host', 'guest', 'late']),
    );
  });

  test('StartMatch from non-host changes nothing', () async {
    guest.send(const StartMatch());
    await guest.expectSilence();

    // State prove: a lobby-triggering command still reports lobby.
    guest.send(const SetReady(ready: true));
    final snapshot = await guest.next() as RoomSnapshot;
    expect(snapshot.phase, RoundPhase.lobby);
  });

  test('host can start the match once everyone is ready', () async {
    host.send(const SetReady(ready: true));
    guest.send(const SetReady(ready: true));
    await host.next(); // host ready snapshot
    await guest.next(); // guest ready snapshot
    await host.next(); // guest ready snapshot to host
    await guest.next(); // host ready snapshot to guest

    host.send(const StartMatch());
    final snapshot = await guest.next() as RoomSnapshot;
    expect(snapshot.phase, RoundPhase.roundPlay);
    expect(snapshot.roundIndex, 0);
  });
}
