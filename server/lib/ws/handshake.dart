import 'dart:convert';

import 'package:tongtong_server/rooms/room_manager.dart';
import 'package:tongtong_server/ws/game_server.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Drives one WebSocket connection: enforces the § 2 handshake (the
/// first message must be `Hello`), then forwards decoded commands to
/// the owning [GameServer].
///
/// Every failure is contained here: invalid frames are dropped and
/// logged (network doc § 6); only protocol-valid-but-unexpected
/// failures or oversized frames close the socket (§ 9: suspect
/// socket). A frame handler must never crash the server.
final class ConnectionSession {
  /// Creates a session pumping [channel] against [server].
  ConnectionSession({required this.server, required this.channel});

  /// Server owning room state and the connection registry.
  final GameServer server;

  /// Raw socket of this connection.
  final WebSocketChannel channel;

  ConnectionId? _connectionId;

  /// Pumps frames until the socket closes, then releases the
  /// connection (network doc § 5 disconnect path).
  Future<void> run() async {
    try {
      await for (final frame in channel.stream) {
        _onFrame(frame);
      }
    } catch (error, stackTrace) {
      server.log('connection stream failed: $error\n$stackTrace');
    }
    server.connectionClosed(_connectionId);
  }

  void _onFrame(Object? frame) {
    if (frame is! String) {
      server.log('dropping non-text frame');
      return;
    }
    final byteLength = utf8.encode(frame).length;
    if (byteLength > maxMessageBytes) {
      server.log(
        'closing socket: frame is $byteLength bytes '
        '(cap $maxMessageBytes, network doc § 6)',
      );
      _closeSocket();
      return;
    }
    final WireMessage message;
    try {
      message = decode(frame);
    } on ProtocolException catch (error) {
      server.log('dropping invalid message: $error');
      return;
    } catch (error) {
      server.log('unexpected decode failure, closing socket: $error');
      _closeSocket();
      return;
    }
    final id = _connectionId;
    if (id == null) {
      _handshake(message);
      return;
    }
    try {
      server.handleCommand(id, message);
    } on ProtocolException catch (error) {
      server.log('dropping message from $id: $error');
    } catch (error, stackTrace) {
      server.log(
        'unexpected routing failure on $id, closing: $error\n$stackTrace',
      );
      _closeSocket();
    }
  }

  void _handshake(WireMessage message) {
    if (message is! Hello) {
      server.log(
        'closing socket: first message was ${message.runtimeType}, '
        'expected Hello (network doc § 2)',
      );
      _closeSocket();
      return;
    }
    final status = checkVersion(message.protocolVersion);
    if (status != VersionStatus.ok) {
      server.log(
        'rejecting handshake from ${message.playerId}: '
        'protocol ${message.protocolVersion} -> $status',
      );
      _sendToSocket(VersionMismatch(status: status));
      _closeSocket();
      return;
    }
    if (server.hub.isPlayerConnected(message.playerId)) {
      server.log(
        'closing socket: ${message.playerId} already connected '
        '(network doc § 6)',
      );
      _sendToSocket(const AlreadyConnected());
      _closeSocket();
      return;
    }
    _connectionId = server.registerConnection(channel, hello: message);
  }

  void _sendToSocket(WireMessage message) {
    try {
      channel.sink.add(encode(message));
    } catch (error) {
      server.log('sink error during handshake reply: $error');
    }
  }

  void _closeSocket() {
    try {
      channel.sink.close();
    } catch (error) {
      server.log('sink close error: $error');
    }
  }
}
