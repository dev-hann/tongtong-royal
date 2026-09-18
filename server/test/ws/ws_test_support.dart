import 'dart:async';
import 'dart:io' show HttpServer;

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tongtong_server/tongtong_server.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Timeout for waiting on a single frame.
const Duration frameTimeout = Duration(seconds: 5);

/// Silence window used to assert that nothing else arrives.
const Duration quietWindow = Duration(milliseconds: 300);

/// Live loopback harness: a real shelf server on an ephemeral port.
final class WsHarness {
  /// Creates a harness wrapping [server] and [http].
  WsHarness(this.server, this.http);

  /// The game server under test.
  final GameServer server;

  /// The bound HTTP server hosting the WebSocket handler.
  final HttpServer http;

  /// WebSocket URL of the bound server.
  Uri get uri => Uri.parse('ws://localhost:${http.port}');

  /// Opens a raw client connection (handshake not yet performed).
  Future<TestClient> connect() async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return TestClient(channel);
  }

  /// Connects and performs a valid `Hello` handshake for [playerId].
  Future<TestClient> connectAndHello(
    String playerId, {
    String nickname = 'nick',
    int version = protocolVersion,
  }) async {
    final client = await connect();
    client.send(
      Hello(
        protocolVersion: version,
        playerId: playerId,
        nickname: nickname,
      ),
    );
    return client;
  }

  /// Stops the HTTP server.
  Future<void> close() => http.close(force: true);
}

/// Starts a real server on an ephemeral loopback port.
Future<WsHarness> startHarness({RoomManager? manager, Log? log}) async {
  final server = GameServer(manager: manager, log: log ?? noopLog);
  final http = await shelf_io.serve(server.handler(), 'localhost', 0);
  return WsHarness(server, http);
}

/// A connected test client with frame buffering helpers.
final class TestClient {
  /// Creates a client pumping [channel].
  TestClient(this.channel) : frames = FrameBuffer(channel.stream);

  /// The raw client socket.
  final WebSocketChannel channel;

  /// Buffered incoming frames.
  final FrameBuffer frames;

  int _playerSeq = 0;

  /// A fresh unique player id.
  String get newPlayerId => 'p${_playerSeq++}';

  /// Sends a typed message.
  void send(WireMessage message) => channel.sink.add(encode(message));

  /// Sends a raw text frame (for invalid-input tests).
  void sendRaw(String text) => channel.sink.add(text);

  /// Waits for the next decoded message; fails if the socket closed.
  Future<WireMessage> next() async {
    final frame = await frames.nextFrame(frameTimeout);
    if (frame == null) {
      throw StateError('connection closed while waiting for a message');
    }
    try {
      return decode(frame);
    } on ProtocolException catch (error) {
      throw StateError('invalid frame from server: $frame ($error)');
    }
  }

  /// Expects the server to close the socket with no further frames.
  Future<void> expectClosed() async {
    final frame = await frames.nextFrame(frameTimeout);
    if (frame != null) {
      throw StateError('expected close, got frame: $frame');
    }
  }

  /// Asserts no frame arrives within [window].
  Future<void> expectSilence([Duration window = quietWindow]) async {
    await Future<void>.delayed(window);
    if (frames.hasFrames) {
      final pending = frames.drainFrames();
      throw StateError('expected silence, got: $pending');
    }
  }

  /// Closes the client side of the socket.
  Future<void> close() => channel.sink.close();
}

/// Buffers frames from a socket stream so tests never lose messages
/// while not actively awaiting.
final class FrameBuffer {
  /// Creates a buffer consuming [stream].
  FrameBuffer(Stream<dynamic> stream) {
    stream.listen(
      (dynamic frame) => _push(frame as String),
      onError: (Object _) => _finish(),
      onDone: _finish,
      cancelOnError: false,
    );
  }

  final List<String> _frames = [];
  final List<Completer<void>> _waiters = [];
  bool _closed = false;

  /// Whether any buffered frame is waiting.
  bool get hasFrames => _frames.isNotEmpty;

  /// Returns and clears all buffered frames.
  List<String> drainFrames() {
    final drained = List<String>.of(_frames);
    _frames.clear();
    return drained;
  }

  /// Waits for the next frame; `null` once the socket is closed and
  /// drained. Throws [TimeoutException] after [timeout].
  Future<String?> nextFrame(Duration timeout) => _waitNext().timeout(timeout);

  Future<String?> _waitNext() async {
    while (_frames.isEmpty && !_closed) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    return _frames.isEmpty ? null : _frames.removeAt(0);
  }

  void _push(String frame) {
    _frames.add(frame);
    _wake();
  }

  void _finish() {
    _closed = true;
    _wake();
  }

  void _wake() {
    for (final waiter in _waiters) {
      waiter.complete();
    }
    _waiters.clear();
  }
}
