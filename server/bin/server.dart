import 'dart:async';

import 'package:tongtong_server/tongtong_server.dart';

/// Bootstrap entrypoint: mounts the WebSocket handler and drives the
/// sweep loop once per second (network doc § 5 grace windows, § 8
/// room TTL). Port defaults to 8080; override with the first CLI
/// argument or `TONGTONG_PORT`.
Future<void> main(List<String> args) async {
  final port = int.tryParse(
        args.isNotEmpty ? args.first : const String.fromEnvironment('PORT'),
      ) ??
      8080;
  final server = GameServer();
  await server.startServer('localhost', port);
  Timer.periodic(
    const Duration(seconds: 1),
    (_) => server.sweep(),
  );
  await Completer<void>().future; // run until killed
}
