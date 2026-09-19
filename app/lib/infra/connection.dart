import 'dart:async';

import 'package:app/infra/net_log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A duplex text transport owned by NetClient.
///
/// Contract (network doc § 9 — no fire-and-forget, no silent catch):
/// - [incoming] delivers server frames and **never errors**; transport
///   failures and remote closes are folded into stream closure (`done`),
///   which the client treats as a disconnect and feeds into the
///   reconnect path.
/// - [send] never throws to its caller; sink errors are logged via the
///   injected [NetLog] and surfaced as a disconnect, not swallowed.
abstract interface class Connection {
  /// Server-to-client text frames; closes when the transport dies.
  Stream<String> get incoming;

  /// Queues [data] for delivery. Implementations must not throw; they
  /// log and fail the transport instead.
  void send(String data);

  /// Closes the transport. Safe to call more than once.
  Future<void> close();
}

/// Creates a [Connection] to [uri]; used by NetClient so tests can
/// substitute scripted fakes at the channel level.
typedef NetConnectionFactory = Future<Connection> Function(Uri uri);

/// [Connection] over `package:web_socket_channel` (thin socket shell).
///
/// All errors — sink failures, connection setup failures via
/// `WebSocketChannel.ready`, stream errors — are caught, logged and
/// converted into closure of [incoming] (network doc § 9).
final class WebSocketConnection implements Connection {
  /// Connects to [uri] and wraps the resulting channel.
  WebSocketConnection.connect(Uri uri, {NetLog? log})
    : _log = log ?? const SilentNetLog(),
      _channel = WebSocketChannel.connect(uri) {
    _subscription = _channel.stream.listen(
      (dynamic data) => _incomingController.add(data as String),
      onError: (Object error, StackTrace stack) =>
          _fail(error, stack, 'stream error'),
      onDone: _incomingController.close,
    );
    // Sink/connection errors surface asynchronously on `ready` and on
    // the sink's `done` future; both are folded into transport failure.
    unawaited(
      _channel.ready.then(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _fail(error, stack, 'connection setup failed');
        },
      ),
    );
    unawaited(
      _channel.sink.done.then(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _fail(error, stack, 'sink failed');
        },
      ),
    );
  }

  final WebSocketChannel _channel;
  final NetLog _log;
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  bool _failed = false;
  bool _closedByUser = false;

  @override
  Stream<String> get incoming => _incomingController.stream;

  @override
  void send(String data) {
    if (_closedByUser || _failed) {
      _log.warn('send ignored: transport already closed');
      return;
    }
    try {
      _channel.sink.add(data);
    } on Object catch (error, stack) {
      _fail(error, stack, 'sync sink add failed');
    }
  }

  @override
  Future<void> close() {
    if (_closedByUser) {
      return Future<void>.value();
    }
    _closedByUser = true;
    // Teardown: cancel errors are irrelevant once closed, but log
    // them rather than swallowing silently (AGENTS 6.5).
    unawaited(
      _subscription.cancel().catchError((Object error) {
        _log.warn('subscription cancel failed: $error');
      }),
    );
    unawaited(_incomingController.close());
    return _channel.sink.close().then(
      (_) {},
      // Sink close errors mean the socket was already gone; the
      // reconnect path owns recovery. Log for diagnostics.
      onError: (Object error, StackTrace stack) {
        _log.warn('close failed: $error');
      },
    );
  }

  void _fail(Object error, StackTrace stack, String reason) {
    if (_failed) {
      return;
    }
    _failed = true;
    _log.error('WebSocket transport failure: $reason', error, stack);
    // Closing the controller makes `incoming` done, which the client
    // translates into the reconnect path (network doc § 9).
    unawaited(_incomingController.close());
    unawaited(
      // Failure path is already terminal; log for diagnostics only.
      _channel.sink.close().then(
        (_) {},
        onError: (Object error) {
          _log.warn('sink close after failure errored: $error');
        },
      ),
    );
  }
}
