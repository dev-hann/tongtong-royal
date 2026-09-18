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

  test('malformed JSON is dropped and the connection survives', () async {
    final client = await harness.connectAndHello('p1');
    client
      ..sendRaw('this is { not json')
      ..sendRaw('{"t":"make_sense","v":{}}') // unknown tag
      ..send(const Ping());
    expect(await client.next(), equals(const Pong()));
  });

  test('oversized frames close the socket', () async {
    final client = await harness.connectAndHello('p1');
    final padding = 'x' * (maxMessageBytes + 512);
    client.sendRaw('{"t":"ping","v":{},"pad":"$padding"}');
    await client.expectClosed();
  });
}
