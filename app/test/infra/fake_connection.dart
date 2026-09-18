import 'dart:async';

import 'package:app/infra/connection.dart';

/// Scripted in-memory [Connection] — the fake server side for tests.
///
/// Tests deliver server frames via [serverSends], kill the transport
/// via [serverCloses], break the sink with [failNextSend], and inspect
/// everything the client put on the wire via [sent] (raw JSON).
final class FakeConnection implements Connection {
  final StreamController<String> _incoming =
      StreamController<String>.broadcast();
  final List<String> sent = <String>[];

  /// When set, the next [send] throws instead of recording — simulates
  /// a broken sink.
  Object? failNextSend;

  /// True once the transport closed for any reason.
  bool closed = false;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  void send(String data) {
    final failure = failNextSend;
    if (failure != null) {
      failNextSend = null;
      throw StateError(failure.toString());
    }
    if (closed) {
      throw StateError('send on closed FakeConnection');
    }
    sent.add(data);
  }

  @override
  Future<void> close() {
    closed = true;
    return _incoming.close().then((_) {});
  }

  /// Delivers a server frame to the client.
  void serverSends(String data) {
    if (!closed) {
      _incoming.add(data);
    }
  }

  /// Server closes the socket cleanly (client sees `done`).
  void serverCloses() {
    closed = true;
    unawaited(_incoming.close());
  }
}
