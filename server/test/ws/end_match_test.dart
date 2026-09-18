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

    host.send(const SetReady(ready: true));
    guest.send(const SetReady(ready: true));
    await host.next(); // host ready snapshot
    await guest.next(); // guest ready snapshot
    await host.next(); // guest ready snapshot to host
    await guest.next(); // host ready snapshot to guest

    host.send(const StartMatch());
    await host.next(); // in-match snapshot
    await guest.next(); // in-match snapshot
  });

  tearDown(() async {
    await harness.close();
  });

  test('host EndMatch returns members to lobby', () async {
    host.send(const EndMatch());
    final hostView = await host.next() as RoomSnapshot;
    expect(hostView.phase, RoundPhase.lobby);
    final guestView = await guest.next() as RoomSnapshot;
    expect(guestView.phase, RoundPhase.lobby);
  });

  test('EndMatch from non-host is dropped with no state change', () async {
    guest.send(const EndMatch());
    await guest.expectSilence();
    await host.expectSilence();

    // State prove: match is still running for the host.
    guest.send(const SetReady(ready: false));
    final snapshot = await guest.next() as RoomSnapshot;
    expect(snapshot.phase, RoundPhase.roundPlay);
  });
}
