/// Support for the E2E integration test (testing doc § 7).
///
/// Workspace-structure note: the "true client" E2E (real `NetClient`
/// from `app/` against the real `GameServer` from `server/`) is not
/// expressible today — `app` does not depend on `server` (nor the
/// reverse), and pubspec edits were out of scope for this task. The
/// E2E therefore lives in `server/test/e2e/` and drives the full wire
/// contract with raw WebSocket clients against the in-process real
/// `GameServer`. The app-side `NetClient` is covered by its own
/// fake-connection unit tests in `app/test/infra/`.
library;

import 'dart:async';
import 'dart:io' show HttpServer;

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tongtong_server/tongtong_server.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Default fail-fast timeout for one wait.
const Duration e2eTimeout = Duration(seconds: 5);

/// Real in-process server on an ephemeral loopback port, plus the
/// collected server log lines for drop/rejection assertions.
final class E2eHarness {
  /// Creates a harness around [server] bound to [http].
  E2eHarness({
    required this.server,
    required this.http,
    required this.logLines,
  });

  /// The game server under test.
  final GameServer server;

  /// The bound HTTP server hosting the WebSocket handler.
  final HttpServer http;

  /// Every line the server logged so far.
  final List<String> logLines;

  /// WebSocket URL of the bound server.
  Uri get uri => Uri.parse('ws://localhost:${http.port}');

  /// Opens a raw client connection and performs the § 2 handshake
  /// (`Hello`, implicit accept) for [playerId].
  Future<E2eClient> connect(String playerId, String nickname) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return E2eClient(channel)
      ..send(
        Hello(
          protocolVersion: protocolVersion,
          playerId: playerId,
          nickname: nickname,
        ),
      );
  }

  /// Stops the HTTP server.
  Future<void> close() => http.close(force: true);
}

/// Boots a real `GameServer` in-process on an ephemeral loopback port,
/// recording its log output (network doc § 6 drop logging).
Future<E2eHarness> startE2e() async {
  final logLines = <String>[];
  final server = GameServer(log: logLines.add);
  final http = await shelf_io.serve(server.handler(), 'localhost', 0);
  return E2eHarness(server: server, http: http, logLines: logLines);
}

/// A loopback WebSocket client speaking the typed wire protocol, with
/// a fail-fast `waitFor` over every message received on the
/// connection (nothing is lost between awaits).
final class E2eClient {
  /// Creates a client pumping [channel].
  E2eClient(this.channel) {
    channel.stream.listen(
      (dynamic frame) => _onFrame(frame as String),
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: false,
    );
  }

  /// The raw client socket.
  final WebSocketChannel channel;

  final List<WireMessage> _messages = <WireMessage>[];
  final List<Completer<void>> _waiters = <Completer<void>>[];
  bool _closed = false;

  /// Every decoded message received so far, oldest first.
  List<WireMessage> get received => List<WireMessage>.unmodifiable(_messages);

  /// Messages received so far matching [T].
  List<T> receivedOf<T extends WireMessage>() =>
      _messages.whereType<T>().toList();

  /// Sends a typed message.
  void send(WireMessage message) => channel.sink.add(encode(message));

  /// Sends a raw text frame (adversarial-input tests, network doc § 6).
  void sendRaw(String text) => channel.sink.add(text);

  /// Waits until a message of [T] matching [predicate] has arrived and
  /// returns it. Fails fast (no hang) after [timeout], or as soon as
  /// the connection closes without a match.
  Future<T> waitFor<T extends WireMessage>(
    bool Function(T) predicate, {
    Duration timeout = e2eTimeout,
    String? because,
  }) async {
    final elapsed = Stopwatch()..start();
    while (true) {
      for (final message in _messages) {
        if (message is T && predicate(message)) {
          return message;
        }
      }
      if (_closed) {
        throw StateError(
          'connection closed while waiting for $T'
          '${because == null ? '' : ' ($because)'}; '
          'received before close: ${_describe()}',
        );
      }
      final remaining = timeout - elapsed.elapsed;
      if (remaining.isNegative) {
        throw StateError(
          'timed out after ${elapsed.elapsed} waiting for $T'
          '${because == null ? '' : ' ($because)'}; '
          'received so far: ${_describe()}',
        );
      }
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future.timeout(remaining);
      } on TimeoutException {
        // Loop once more so the deadline branch reports the failure.
      } finally {
        _waiters.remove(waiter);
      }
    }
  }

  /// Closes the client side of the socket.
  Future<void> close() => channel.sink.close();

  void _onFrame(String frame) {
    try {
      _messages.add(decode(frame));
    } on ProtocolException catch (error) {
      throw StateError('invalid frame from server: $frame ($error)');
    }
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _waiters.clear();
  }

  void _finish() {
    _closed = true;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _waiters.clear();
  }

  String _describe() =>
      _messages.map((m) => m.runtimeType.toString()).join(', ');
}
