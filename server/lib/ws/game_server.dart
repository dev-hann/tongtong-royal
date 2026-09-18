import 'dart:async';
import 'dart:io' show HttpServer;

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:tongtong_server/rooms/clock.dart';
import 'package:tongtong_server/rooms/room_manager.dart';
import 'package:tongtong_server/rooms/room_state.dart';
import 'package:tongtong_server/ws/connection_hub.dart';
import 'package:tongtong_server/ws/handshake.dart';
import 'package:tongtong_server/ws/log.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Input-relay sanity cap: messages per second per connection before
/// excess input is dropped silently (network doc § 3 — sanity bound,
/// not judging).
const int inputRateLimit = 120;

/// Sliding window for [inputRateLimit].
const int inputRateWindowMs = 1000;

/// Shelf WebSocket server wiring the [RoomManager] room core to the
/// wire protocol (network doc § 2 handshake, § 3 sanity bounds, § 6
/// adversarial policy).
///
/// The server holds connection lifecycle and relay logic only — no
/// game rules (AGENTS § 6.3): phases stay lobby/inMatch and round
/// data stays opaque.
final class GameServer {
  /// Creates a server around [manager] (default: a manager on the
  /// wall clock). [log] receives operational noise; default drops it.
  GameServer({RoomManager? manager, this.log = noopLog})
    : manager = manager ?? RoomManager(clock: _wallClockMs);

  static int _wallClockMs() => DateTime.now().millisecondsSinceEpoch;

  /// Room lifecycle core; timestamps come from its injected clock.
  final RoomManager manager;

  /// Logging seam for drops, rejects and relay denials.
  final Log log;

  /// Live connection registry.
  late final ConnectionHub hub = ConnectionHub(logger: log);

  /// Input rate caps keyed by connection.
  late final _InputRateLimiter _inputRate = _InputRateLimiter(
    clock: manager.clock,
  );

  /// Number of live rooms.
  int get roomCount => manager.roomCount;

  /// Shelf handler upgrading requests to WebSocket connections.
  Handler handler() => webSocketHandler(
    (WebSocketChannel channel, String? _) =>
        unawaited(ConnectionSession(server: this, channel: channel).run()),
  );

  /// Bootstrap helper: binds [handler] with shelf's IO server on
  /// [address]:[port] (port 0 picks an ephemeral port).
  Future<HttpServer> startServer(Object address, int port) =>
      shelf_io.serve(handler(), address, port);

  /// Registers a connection whose `Hello` passed handshake checks.
  ConnectionId registerConnection(
    WebSocketChannel channel, {
    required Hello hello,
  }) =>
      hub.register(channel, playerId: hello.playerId, nickname: hello.nickname);

  /// Routes one decoded command from [id] (network doc § 6: messages
  /// invalid for the current state are dropped and logged, never
  /// crash).
  void handleCommand(ConnectionId id, WireMessage message) {
    switch (message) {
      case Ping():
        hub.send(id, const Pong());
      case CreateRoom():
        _createRoom(id);
      case JoinRoom(:final code):
        _joinRoom(id, code);
      case RejoinRoom(:final code):
        _rejoinRoom(id, code);
      case LeaveRoom():
        _leaveRoom(id);
      case SetReady(:final ready):
        _setReady(id, ready);
      case StartMatch():
        _startMatch(id);
      case EndMatch():
        _endMatch(id);
      case PlayerInputMessage():
        _relayInput(id, message);
      case Snapshot() ||
          RoundStarting() ||
          RoundResultsMessage() ||
          RoomClosed():
        _relayFromHost(id, message);
      default:
        log('dropping ${message.runtimeType} from $id: not valid here');
    }
  }

  /// Releases a closed connection (network doc § 5): the room core
  /// marks the seat disconnected and arms its grace window, then the
  /// remaining members receive an updated snapshot.
  void connectionClosed(ConnectionId? id) {
    if (id == null || !hub.contains(id)) {
      return;
    }
    final roomCode = hub.roomOf(id);
    _inputRate.forget(id);
    manager.disconnect(id);
    hub.unregister(id);
    if (roomCode != null) {
      _broadcastSnapshot(roomCode);
    }
  }

  /// Runs deadline detection once and applies its events (network
  /// doc § 5.1, § 5.2, § 8): host-grace expiry closes the room for
  /// everyone, player-grace expiry refreshes the snapshot, empty-room
  /// TTL only cleans up. Returns the raw events for observability.
  List<SweepEvent> sweep() {
    final events = manager.sweep(manager.clock());
    for (final event in events) {
      switch (event) {
        case HostGraceExpired():
          _closeRoom(event.roomCode, RoomCloseReason.hostLeft);
        case PlayerGraceExpired():
          _broadcastSnapshot(event.roomCode);
        case EmptyRoomExpired():
          hub.clearRoom(event.roomCode);
      }
    }
    return events;
  }

  void _createRoom(ConnectionId id) {
    final connection = hub.connection(id);
    if (connection == null) {
      return;
    }
    final result = manager.createRoom(
      connectionId: id,
      playerId: connection.playerId,
      nickname: connection.nickname,
      identity: _identityOf(connection),
    );
    switch (result.status) {
      case CreateRoomStatus.ok:
        hub.joinRoom(id, result.roomCode);
        _broadcastSnapshot(result.roomCode);
      case CreateRoomStatus.serverFull:
        hub.send(id, const ServerFull());
      case CreateRoomStatus.rateLimited:
        _rejectAndClose(id, const RateLimited());
      case CreateRoomStatus.alreadyConnected:
        hub.send(id, const AlreadyConnected());
    }
  }

  void _joinRoom(ConnectionId id, String code) {
    final connection = hub.connection(id);
    if (connection == null) {
      return;
    }
    final status = manager.joinRoom(
      code: code,
      connectionId: id,
      playerId: connection.playerId,
      nickname: connection.nickname,
      identity: _identityOf(connection),
    );
    switch (status) {
      case JoinRoomStatus.ok:
      case JoinRoomStatus.joinedAsSpectator:
        hub.joinRoom(id, code);
        _broadcastSnapshot(code);
      case JoinRoomStatus.notFound:
        hub.send(id, const JoinFailed(reason: JoinFailReason.notFound));
      case JoinRoomStatus.roomFull:
        hub.send(id, const JoinFailed(reason: JoinFailReason.roomFull));
      case JoinRoomStatus.alreadyConnected:
        hub.send(id, const AlreadyConnected());
      case JoinRoomStatus.rateLimited:
        _rejectAndClose(id, const RateLimited());
    }
  }

  void _rejoinRoom(ConnectionId id, String code) {
    final connection = hub.connection(id);
    if (connection == null) {
      return;
    }
    final status = manager.rejoinRoom(
      code: code,
      connectionId: id,
      playerId: connection.playerId,
      nickname: connection.nickname,
      identity: _identityOf(connection),
    );
    switch (status) {
      case RejoinRoomStatus.ok:
      case RejoinRoomStatus.matchForfeit:
        hub.joinRoom(id, code);
        _broadcastSnapshot(code);
      case RejoinRoomStatus.notFound:
        hub.send(id, const JoinFailed(reason: JoinFailReason.notFound));
      case RejoinRoomStatus.roomFull:
        hub.send(id, const JoinFailed(reason: JoinFailReason.roomFull));
      case RejoinRoomStatus.alreadyConnected:
        hub.send(id, const AlreadyConnected());
      case RejoinRoomStatus.rateLimited:
        _rejectAndClose(id, const RateLimited());
    }
  }

  void _leaveRoom(ConnectionId id) {
    final roomCode = hub.roomOf(id);
    if (roomCode == null) {
      log('leave from $id rejected: not in a room');
      return;
    }
    final status = manager.leaveRoom(id);
    switch (status) {
      case LeaveRoomStatus.left:
        hub.leaveRoom(id);
        _broadcastSnapshot(roomCode);
      case LeaveRoomStatus.roomClosed:
        // Host left while others remain: close at once (network § 8).
        hub.leaveRoom(id);
        _closeRoom(roomCode, RoomCloseReason.hostLeft);
      case LeaveRoomStatus.notInRoom:
        log('leave from $id rejected: no seat');
    }
  }

  void _setReady(ConnectionId id, bool ready) {
    switch (manager.setReady(connectionId: id, ready: ready)) {
      case SetReadyStatus.ok:
        final roomCode = hub.roomOf(id);
        if (roomCode != null) {
          _broadcastSnapshot(roomCode);
        }
      case SetReadyStatus.notInRoom:
        log('setReady from $id rejected: not in a room');
    }
  }

  void _startMatch(ConnectionId id) {
    switch (manager.startMatch(id)) {
      case StartMatchStatus.ok:
        final roomCode = hub.roomOf(id);
        if (roomCode != null) {
          _broadcastSnapshot(roomCode);
        }
      case StartMatchStatus.notInRoom:
        log('startMatch from $id dropped: not in a room');
      case StartMatchStatus.notHost:
        log('startMatch from $id dropped: sender is not the host');
      case StartMatchStatus.playersNotReady:
        log('startMatch from $id dropped: players not ready');
      case StartMatchStatus.tooFewPlayers:
        log('startMatch from $id dropped: too few players');
    }
  }

  void _endMatch(ConnectionId id) {
    switch (manager.endMatch(id)) {
      case EndMatchStatus.ok:
        final roomCode = hub.roomOf(id);
        if (roomCode != null) {
          _broadcastSnapshot(roomCode);
        }
      case EndMatchStatus.notInRoom:
        log('endMatch from $id dropped: not in a room');
      case EndMatchStatus.notHost:
        log('endMatch from $id dropped: sender is not the host');
      case EndMatchStatus.notInMatch:
        log('endMatch from $id dropped: no match is running');
    }
  }

  void _relayInput(ConnectionId id, PlayerInputMessage input) {
    final roomCode = hub.roomOf(id);
    if (roomCode == null) {
      log('input from $id dropped: not in a room');
      return;
    }
    final room = manager.roomByCode(roomCode);
    if (room == null || room.players[id] == null) {
      log('input from $id dropped: no seat in $roomCode');
      return;
    }
    if (room.hostConnectionId == id) {
      return; // Host consumes its own input locally.
    }
    if (!_inputRate.allow(id)) {
      log('input from $id dropped: over $inputRateLimit msgs/s');
      return;
    }
    hub.send(room.hostConnectionId, input);
  }

  void _relayFromHost(ConnectionId id, WireMessage message) {
    final roomCode = hub.roomOf(id);
    if (roomCode == null) {
      log('${message.runtimeType} from $id dropped: not in a room');
      return;
    }
    final room = manager.roomByCode(roomCode);
    if (room == null) {
      log('${message.runtimeType} from $id dropped: room gone');
      return;
    }
    if (room.hostConnectionId != id) {
      log(
        '${message.runtimeType} from $id dropped: sender is not the host '
        '(network doc § 3)',
      );
      return;
    }
    hub.broadcast(roomCode, message, except: id);
  }

  /// Rate identity for the room core (network doc § 5.4 says per-IP;
  /// the WS adapter cannot see the remote address through
  /// `shelf_web_socket`, so the player id is used as the stable
  /// fallback — spec gap, see task report).
  String _identityOf(Connection connection) => connection.playerId;

  void _rejectAndClose(ConnectionId id, WireMessage message) {
    hub
      ..send(id, message)
      ..close(id);
  }

  void _broadcastSnapshot(String roomCode, {ConnectionId? except}) {
    final room = manager.roomByCode(roomCode);
    if (room == null) {
      return;
    }
    hub.broadcast(roomCode, _snapshotOf(room), except: except);
  }

  RoomSnapshot _snapshotOf(Room room) => RoomSnapshot(
    code: room.code,
    players: [
      // Reserved (disconnected) grace seats stay listed with
      // connected:false so clients can render them (network § 5,
      // § 8); spectators carry isSpectator:true.
      for (final seat in room.players.values)
        PlayerInfo(
          playerId: seat.playerId,
          nickname: seat.nickname,
          ready: seat.ready,
          connected: seat.connected,
          isSpectator: seat.isSpectator,
        ),
    ],
    // The server only knows lobby/inMatch; a running match is
    // reported as roundPlay (protocol approximation, see report).
    phase: room.phase == RoomPhase.inMatch
        ? RoundPhase.roundPlay
        : RoundPhase.lobby,
    roundIndex: room.roundIndex,
  );

  void _closeRoom(String roomCode, RoomCloseReason reason) {
    for (final id in hub.members(roomCode)) {
      hub
        ..send(id, RoomClosed(reason: reason))
        ..leaveRoom(id)
        ..close(id);
    }
    hub.clearRoom(roomCode);
  }
}

/// Sliding-window per-connection input limiter (network doc § 3).
final class _InputRateLimiter {
  _InputRateLimiter({required this.clock});

  final Clock clock;
  final Map<ConnectionId, List<int>> _stamps = {};

  bool allow(ConnectionId id) {
    final nowMs = clock();
    final stamps = _stamps.putIfAbsent(id, () => <int>[])
      ..removeWhere((t) => t <= nowMs - inputRateWindowMs);
    final allowed = stamps.length < inputRateLimit;
    if (allowed) {
      stamps.add(nowMs);
    }
    return allowed;
  }

  void forget(ConnectionId id) => _stamps.remove(id);
}
