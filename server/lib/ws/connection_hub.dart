import 'package:tongtong_server/rooms/room_manager.dart' show ConnectionId;
import 'package:tongtong_server/ws/log.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live connection record kept by the hub.
final class Connection {
  /// Creates a record for a handshaked socket.
  Connection({
    required this.channel,
    required this.playerId,
    required this.nickname,
  });

  /// The socket of this connection.
  final WebSocketChannel channel;

  /// Player identity declared at handshake time.
  final PlayerId playerId;

  /// Display name declared at handshake time.
  final String nickname;

  /// Room this connection is currently seated in, if any.
  String? roomCode;
}

/// Registry of live connections: connection id → socket, player
/// identity and room membership (network doc § 2, § 6).
///
/// The hub is transport-only bookkeeping; room rules stay in
/// `RoomManager`. Every send goes through [send]/[broadcast], which
/// contain sink errors instead of throwing (network doc § 9: no
/// fire-and-forget sends, no crash on broken pipes).
final class ConnectionHub {
  /// Creates a hub logging through [logger].
  ConnectionHub({Log logger = noopLog}) : _log = logger;

  final Log _log;
  final Map<ConnectionId, Connection> _connections = {};
  final Map<PlayerId, ConnectionId> _connectionOfPlayer = {};
  final Map<String, Set<ConnectionId>> _membersByRoom = {};
  int _nextId = 0;

  /// Number of live connections.
  int get connectionCount => _connections.length;

  /// Whether [id] is a registered connection.
  bool contains(ConnectionId id) => _connections.containsKey(id);

  /// Whether [playerId] currently has a live socket (network doc § 6:
  /// first socket wins, duplicates are rejected at handshake).
  bool isPlayerConnected(PlayerId playerId) =>
      _connections[_connectionOfPlayer[playerId]] != null;

  /// Registers a handshaked socket; returns its fresh connection id.
  ConnectionId register(
    WebSocketChannel channel, {
    required PlayerId playerId,
    required String nickname,
  }) {
    final id = 'conn-$_nextId';
    _nextId++;
    _connections[id] = Connection(
      channel: channel,
      playerId: playerId,
      nickname: nickname,
    );
    _connectionOfPlayer[playerId] = id;
    return id;
  }

  /// Removes a connection and all its memberships.
  void unregister(ConnectionId id) {
    final connection = _connections.remove(id);
    if (connection == null) {
      return;
    }
    if (_connectionOfPlayer[connection.playerId] == id) {
      _connectionOfPlayer.remove(connection.playerId);
    }
    final roomCode = connection.roomCode;
    if (roomCode != null) {
      leaveRoom(id);
    }
  }

  /// Returns the connection record for [id], or `null`.
  Connection? connection(ConnectionId id) => _connections[id];

  /// Seats a connection in a room.
  void joinRoom(ConnectionId id, String roomCode) {
    final connection = _connections[id];
    if (connection == null) {
      return;
    }
    connection.roomCode = roomCode;
    _membersByRoom.putIfAbsent(roomCode, () => {}).add(id);
  }

  /// Removes a connection's room membership, if any.
  void leaveRoom(ConnectionId id) {
    final connection = _connections[id];
    if (connection == null) {
      return;
    }
    final roomCode = connection.roomCode;
    connection.roomCode = null;
    final members = roomCode == null ? null : _membersByRoom[roomCode];
    if (members == null) {
      return;
    }
    members.remove(id);
    if (members.isEmpty) {
      _membersByRoom.remove(roomCode);
    }
  }

  /// Room code the connection is seated in, or `null`.
  String? roomOf(ConnectionId id) => _connections[id]?.roomCode;

  /// Live member connection ids of a room (snapshot copy).
  List<ConnectionId> members(String roomCode) =>
      (_membersByRoom[roomCode] ?? const <ConnectionId>[]).toList();

  /// Forgets a room's membership list entirely (room gone).
  void clearRoom(String roomCode) => _membersByRoom.remove(roomCode);

  /// Sends [message] to one connection; sink errors are logged, never
  /// thrown (network doc § 9).
  void send(ConnectionId id, WireMessage message) {
    final connection = _connections[id];
    if (connection == null) {
      return;
    }
    try {
      connection.channel.sink.add(encode(message));
    } catch (error) {
      _log('sink error sending to $id: $error');
    }
  }

  /// Sends [message] to every member of a room except [except].
  void broadcast(
    String roomCode,
    WireMessage message, {
    ConnectionId? except,
  }) {
    for (final id in members(roomCode)) {
      if (id == except) {
        continue;
      }
      send(id, message);
    }
  }

  /// Closes one connection's socket; close errors are logged.
  void close(ConnectionId id) {
    final connection = _connections[id];
    if (connection == null) {
      return;
    }
    try {
      connection.channel.sink.close();
    } catch (error) {
      _log('sink close error on $id: $error');
    }
  }
}
