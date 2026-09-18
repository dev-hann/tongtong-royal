import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'ws_test_support.dart';

void main() {
  late WsHarness harness;

  setUp(() async {
    harness = await startHarness();
  });

  tearDown(() async {
    await harness.close();
  });

  test('rejects too-old protocol version with VersionMismatch and closes',
      () async {
    final client = await harness.connect();
    client.send(
      const Hello(
        protocolVersion: protocolVersion - 2,
        playerId: 'p1',
        nickname: 'old',
      ),
    );
    expect(
      await client.next(),
      equals(
        const VersionMismatch(status: VersionStatus.clientTooOld),
      ),
    );
    await client.expectClosed();
  });

  test('rejects newer client version with VersionMismatch and closes',
      () async {
    final client = await harness.connect();
    client.send(
      const Hello(
        protocolVersion: protocolVersion + 1,
        playerId: 'p1',
        nickname: 'new',
      ),
    );
    expect(
      await client.next(),
      equals(
        const VersionMismatch(status: VersionStatus.serverTooOld),
      ),
    );
    await client.expectClosed();
  });

  test('closes the socket when the first message is not Hello', () async {
    final client = await harness.connect();
    client.send(const Ping());
    await client.expectClosed();
  });

  test('rejects duplicate playerId with AlreadyConnected and closes',
      () async {
    await harness.connectAndHello('dup');

    final second = await harness.connect();
    second.send(
      const Hello(
        protocolVersion: protocolVersion,
        playerId: 'dup',
        nickname: 'clone',
      ),
    );
    expect(await second.next(), equals(const AlreadyConnected()));
    await second.expectClosed();
  });

  test('accepts a valid Hello and keeps routing commands', () async {
    final client = await harness.connectAndHello('p1');
    client.send(const Ping());
    expect(await client.next(), equals(const Pong()));
  });
}
