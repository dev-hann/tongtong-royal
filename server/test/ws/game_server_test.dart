import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_test_support.dart';

void main() {
  test('startServer binds a real port serving the WS handler', () async {
    final server = GameServer();
    final http = await server.startServer('localhost', 0);
    addTearDown(() => http.close(force: true));

    final channel =
        WebSocketChannel.connect(Uri.parse('ws://localhost:${http.port}'));
    await channel.ready;
    final client = TestClient(channel);
    addTearDown(client.close);

    client.send(
      const Hello(
        protocolVersion: protocolVersion,
        playerId: 'boot',
        nickname: 'boot',
      ),
    );
    expect(await (client..send(const Ping())).next(), equals(const Pong()));
  });

  test('injected log receives dropped-message notices', () async {
    final lines = <String>[];
    final harness = await startHarness(log: lines.add);
    addTearDown(harness.close);

    final client = await harness.connectAndHello('p1');
    client
      ..sendRaw('nonsense')
      ..send(const Ping());
    expect(await client.next(), equals(const Pong()));
    expect(lines, isNotEmpty);
    expect(lines.first, contains('invalid message'));
  });
}
