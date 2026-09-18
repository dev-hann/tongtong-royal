import 'dart:math';

import 'package:tongtong_server/rooms/clock.dart';
import 'package:tongtong_server/rooms/room_code.dart';
import 'package:tongtong_server/rooms/room_state.dart';

/// Connection identifier (one live WebSocket).
typedef ConnectionId = String;

/// Player identity from the handshake (client-generated UUID).
typedef PlayerId = String;

/// Rate-limit identity (per-IP key supplied by the adapter,
/// network doc § 5.4).
typedef RateIdentity = String;

/// Default maximum number of concurrent rooms (network doc § 8).
const int defaultMaxRooms = 200;

/// Reconnect grace window for host and players (network doc § 5).
const int graceWindowMs = 10000;

/// Empty-room TTL before deletion and code recycling (network § 8).
const int emptyRoomTtlMs = 300000;

/// Sliding window for join/rejoin and create rate limits (net § 5.4).
const int rateWindowMs = 60000;

/// Maximum join+rejoin attempts per identity per window (net § 5.4).
const int joinRateLimit = 10;

/// Maximum room creations per identity per window (network § 5.4).
const int createRateLimit = 5;

/// Maximum seats (players + reserved + spectators) per room.
///
/// The GDD caps matches at 4 players; the network doc does not state
/// overflow behavior, so the server rejects joins beyond 4 total
/// seats. Spec gap — needs doc sync (see task report).
const int roomSeatCapacity = 4;

/// Minimum connected non-spectator players to start a match
/// (GDD § 7.1).
const int minPlayersToStart = 2;

/// Outcome of `RoomManager.createRoom`.
enum CreateRoomStatus {
  /// Room created; caller is host.
  ok,

  /// Concurrent-room cap reached (network doc § 8).
  serverFull,

  /// Create rate limit exceeded (network doc § 5.4).
  rateLimited,

  /// Connection is already seated in some room.
  alreadyConnected,
}

/// Result of `RoomManager.createRoom`.
final class CreateRoomResult {
  /// Creates a result.
  const CreateRoomResult(this.status, this.roomCode);

  /// Outcome kind.
  final CreateRoomStatus status;

  /// Code of the created room; empty unless status is
  /// [CreateRoomStatus.ok].
  final String roomCode;
}

/// Outcome of `RoomManager.joinRoom`.
enum JoinRoomStatus {
  /// Joined as a regular player (lobby phase).
  ok,

  /// Joined as spectator for the current match (network doc § 8).
  joinedAsSpectator,

  /// No live room with that code.
  notFound,

  /// Same playerId already holds a live or reserved seat
  /// (network doc § 6 duplicate-join rule).
  alreadyConnected,

  /// Room already holds the maximum number of seats.
  roomFull,

  /// Join/rejoin rate limit exceeded (network doc § 5.4).
  rateLimited,
}

/// Outcome of `RoomManager.rejoinRoom`.
enum RejoinRoomStatus {
  /// Seat resumed (within grace) or re-entered while in lobby.
  ok,

  /// Seat was gone past grace during a match: re-entered as
  /// spectator and the current match is forfeit (network § 5.2).
  matchForfeit,

  /// No live room with that code.
  notFound,

  /// PlayerId already connected on another socket (network § 6).
  alreadyConnected,

  /// Room already holds the maximum number of seats.
  roomFull,

  /// Join/rejoin rate limit exceeded (network doc § 5.4).
  rateLimited,
}

/// Outcome of `RoomManager.setReady`.
enum SetReadyStatus {
  /// Flag updated.
  ok,

  /// Connection holds no seat.
  notInRoom,
}

/// Outcome of `RoomManager.startMatch`.
enum StartMatchStatus {
  /// Match started; phase is now [RoomPhase.inMatch].
  ok,

  /// Connection holds no seat.
  notInRoom,

  /// Caller is not the host (GDD § 7.1).
  notHost,

  /// Some connected player is not ready (GDD § 7.1).
  playersNotReady,

  /// Fewer than [minPlayersToStart] connected players (GDD § 7.1).
  tooFewPlayers,
}

/// Outcome of `RoomManager.endMatch`.
enum EndMatchStatus {
  /// Phase returned to lobby; spectators became players.
  ok,

  /// Connection holds no seat.
  notInRoom,

  /// Caller is not the host.
  notHost,

  /// No match is running.
  notInMatch,
}

/// Outcome of `RoomManager.leaveRoom`.
enum LeaveRoomStatus {
  /// Seat removed; room continues.
  left,

  /// Host left: room closed immediately (reason `hostLeft`), all
  /// remaining seats dropped, invite code recycled.
  roomClosed,

  /// Connection holds no seat.
  notInRoom,
}

/// Deadline-expiry event emitted by `RoomManager.sweep`.
sealed class SweepEvent {
  /// Creates an event for [roomCode].
  const SweepEvent(this.roomCode);

  /// Code of the room the event belongs to.
  final String roomCode;
}

/// Host grace window expired: room must be closed with
/// `RoomClosed { reason: hostLeft }` (network doc § 5.1).
final class HostGraceExpired extends SweepEvent {
  /// Creates the event.
  const HostGraceExpired(super.roomCode);
}

/// Non-host grace window expired: seat removed. [forfeited] is true
/// when a match was running and the seat was a player seat; the match
/// itself continues (network doc § 5.2).
final class PlayerGraceExpired extends SweepEvent {
  /// Creates the event.
  const PlayerGraceExpired(
    super.roomCode, {
    required this.playerId,
    required this.forfeited,
  });

  /// Player whose reserved seat expired.
  final PlayerId playerId;

  /// Whether the current match is forfeit for that player.
  final bool forfeited;
}

/// Empty-room TTL expired: room deleted, invite code recycled
/// (network doc § 8).
final class EmptyRoomExpired extends SweepEvent {
  /// Creates the event.
  const EmptyRoomExpired(super.roomCode);
}

/// Per-identity sliding-window attempt counters (network doc § 5.4).
final class _RateCounters {
  final List<int> joinAttempts = [];
  final List<int> createAttempts = [];
}

/// Pure, synchronous room-lifecycle core for the relay server.
///
/// Owns invite codes, seats, grace windows, and rate budgets
/// (network doc § 5 and § 8). Knows nothing about game rules: phases
/// are lobby/inMatch only and [Room.roundIndex] is opaque
/// (architecture doc § 1). No sockets, no I/O, no wall-clock time —
/// all timestamps come from [clock], and expiry is detected only when
/// the adapter calls [sweep] with the current time.
final class RoomManager {
  /// Creates a manager.
  ///
  /// [codeRandom] seeds invite-code generation; inject a deterministic
  /// [Random] in tests. [maxRooms] is the concurrent-room cap
  /// (network doc § 8, default [defaultMaxRooms]).
  RoomManager({
    required this.clock,
    Random? codeRandom,
    this.maxRooms = defaultMaxRooms,
  }) : _codeRandom = codeRandom ?? Random();

  /// Injected time source; wall-clock time is never read directly.
  final Clock clock;

  /// Maximum number of concurrent rooms (network doc § 8).
  final int maxRooms;

  final Random _codeRandom;
  final Map<String, Room> _rooms = {};
  final Map<ConnectionId, String> _roomOfConnection = {};
  final Map<RateIdentity, _RateCounters> _rateCounters = {};


  /// Creates a room; the creator becomes host (network doc § 8).
  ///
  /// Codes are regenerated on collision with any live room.
  CreateRoomResult createRoom({
    required ConnectionId connectionId,
    required PlayerId playerId,
    required String nickname,
    required RateIdentity identity,
  }) {
    final nowMs = clock();
    if (!_record(_counters(identity).createAttempts, createRateLimit,
        nowMs)) {
      return const CreateRoomResult(CreateRoomStatus.rateLimited, '');
    }
    if (_rooms.length >= maxRooms) {
      return const CreateRoomResult(CreateRoomStatus.serverFull, '');
    }
    if (_roomOfConnection.containsKey(connectionId)) {
      return const CreateRoomResult(
        CreateRoomStatus.alreadyConnected,
        '',
      );
    }
    final room = Room(
      code: _freeCode(),
      hostConnectionId: connectionId,
      createdAtMs: nowMs,
    );
    room.players[connectionId] = PlayerSeat(
      playerId: playerId,
      nickname: nickname,
    );
    _rooms[room.code] = room;
    _roomOfConnection[connectionId] = room.code;
    return CreateRoomResult(CreateRoomStatus.ok, room.code);
  }

  /// Joins a room by invite code.
  ///
  /// Mid-match joins succeed only as spectators for the current match
  /// (network doc § 8). Same playerId on a second socket yields
  /// [JoinRoomStatus.alreadyConnected] (network doc § 6).
  JoinRoomStatus joinRoom({
    required String code,
    required ConnectionId connectionId,
    required PlayerId playerId,
    required String nickname,
    required RateIdentity identity,
  }) {
    final nowMs = clock();
    if (!_record(_counters(identity).joinAttempts, joinRateLimit, nowMs)) {
      return JoinRoomStatus.rateLimited;
    }
    if (_roomOfConnection.containsKey(connectionId)) {
      return JoinRoomStatus.alreadyConnected;
    }
    final room = _rooms[code];
    if (room == null) return JoinRoomStatus.notFound;
    if (room.seatOfPlayer(playerId) != null) {
      return JoinRoomStatus.alreadyConnected;
    }
    if (room.players.length >= roomSeatCapacity) {
      return JoinRoomStatus.roomFull;
    }
    final spectator = room.phase == RoomPhase.inMatch;
    room.players[connectionId] = PlayerSeat(
      playerId: playerId,
      nickname: nickname,
      isSpectator: spectator,
    );
    _roomOfConnection[connectionId] = code;
    room.lastOccupiedAtMs = nowMs;
    return spectator ? JoinRoomStatus.joinedAsSpectator : JoinRoomStatus.ok;
  }

  /// Rejoins a reserved seat by playerId (network doc § 5).
  ///
  /// Within the grace window the seat is rebound to the new
  /// connection. Past grace during a match the player re-enters as a
  /// spectator and the match is forfeit (§ 5.2). Past grace in lobby
  /// the player simply re-enters.
  RejoinRoomStatus rejoinRoom({
    required String code,
    required ConnectionId connectionId,
    required PlayerId playerId,
    required String nickname,
    required RateIdentity identity,
  }) {
    final nowMs = clock();
    if (!_record(_counters(identity).joinAttempts, joinRateLimit, nowMs)) {
      return RejoinRoomStatus.rateLimited;
    }
    if (_roomOfConnection.containsKey(connectionId)) {
      return RejoinRoomStatus.alreadyConnected;
    }
    final room = _rooms[code];
    if (room == null) return RejoinRoomStatus.notFound;
    final seat = room.seatOfPlayer(playerId);
    if (seat == null) {
      return _enterRoom(room, connectionId, playerId, nickname, nowMs);
    }
    if (seat.connected) return RejoinRoomStatus.alreadyConnected;
    final expired =
        nowMs - seat.disconnectedAtMs! >= graceWindowMs;
    final oldConnection = room.connectionOfSeat(seat)!;
    if (expired) {
      _removeSeat(room, oldConnection);
      return _enterRoom(room, connectionId, playerId, nickname, nowMs);
    }
    room.players
      ..remove(oldConnection)
      ..[connectionId] = seat;
    seat
      ..connected = true
      ..disconnectedAtMs = null;
    if (room.hostConnectionId == oldConnection) {
      room.hostConnectionId = connectionId;
    }
    _roomOfConnection[connectionId] = code;
    room.lastOccupiedAtMs = nowMs;
    return RejoinRoomStatus.ok;
  }

  /// Marks the seat disconnected and starts its grace window
  /// (network doc § 5). Host disconnect arms the 10 s host grace.
  void disconnect(ConnectionId connectionId) {
    final code = _roomOfConnection[connectionId];
    if (code == null) return;
    final room = _rooms[code];
    if (room == null) return;
    final seat = room.players[connectionId];
    if (seat == null || !seat.connected) return;
    final nowMs = clock();
    seat
      ..connected = false
      ..disconnectedAtMs = nowMs;
    room.lastOccupiedAtMs = nowMs;
  }

  /// Sets the caller's ready flag (lobby phase, GDD § 7.1).
  SetReadyStatus setReady({
    required ConnectionId connectionId,
    required bool ready,
  }) {
    final room = _roomOf(connectionId);
    if (room == null) return SetReadyStatus.notInRoom;
    room.players[connectionId]!.ready = ready;
    return SetReadyStatus.ok;
  }

  /// Starts a match from lobby (GDD § 7.1): host only, every
  /// connected player ready, at least [minPlayersToStart] players.
  StartMatchStatus startMatch(ConnectionId connectionId) {
    final room = _roomOf(connectionId);
    if (room == null) return StartMatchStatus.notInRoom;
    if (room.hostConnectionId != connectionId) {
      return StartMatchStatus.notHost;
    }
    final active = room.players.values
        .where((seat) => seat.connected && !seat.isSpectator)
        .toList();
    if (active.any((seat) => !seat.ready)) {
      return StartMatchStatus.playersNotReady;
    }
    if (active.length < minPlayersToStart) {
      return StartMatchStatus.tooFewPlayers;
    }
    room
      ..phase = RoomPhase.inMatch
      ..roundIndex = 0;
    return StartMatchStatus.ok;
  }

  /// Ends the running match: phase back to lobby, spectators become
  /// players, ready flags reset (GDD § 1 core loop back to lobby).
  EndMatchStatus endMatch(ConnectionId connectionId) {
    final room = _roomOf(connectionId);
    if (room == null) return EndMatchStatus.notInRoom;
    if (room.hostConnectionId != connectionId) return EndMatchStatus.notHost;
    if (room.phase != RoomPhase.inMatch) return EndMatchStatus.notInMatch;
    room
      ..phase = RoomPhase.lobby
      ..roundIndex = 0;
    for (final seat in room.players.values) {
      seat
        ..isSpectator = false
        ..ready = false;
    }
    return EndMatchStatus.ok;
  }

  /// Removes the seat immediately. The host leaving while anybody
  /// remains closes the room at once with reason `hostLeft`; the last
  /// human leaving anchors the 5-minute empty-room TTL (network § 8).
  LeaveRoomStatus leaveRoom(ConnectionId connectionId) {
    final code = _roomOfConnection[connectionId];
    if (code == null) return LeaveRoomStatus.notInRoom;
    final room = _rooms[code]!;
    final wasHost = room.hostConnectionId == connectionId;
    _removeSeat(room, connectionId);
    room.lastOccupiedAtMs = clock();
    if (wasHost && room.players.isNotEmpty) {
      _deleteRoom(room);
      return LeaveRoomStatus.roomClosed;
    }
    return LeaveRoomStatus.left;
  }

  /// Detects expired deadlines at [nowMs] and returns the events, in
  /// this order per room: host grace, player grace, empty-room TTL.
  /// Also prunes idle rate counters. Idempotent; call as often as the
  /// adapter wants (e.g. once per second).
  List<SweepEvent> sweep(int nowMs) {
    final events = <SweepEvent>[];
    for (final room in _rooms.values.toList()) {
      if (_sweepHostGrace(room, nowMs, events)) continue;
      _sweepPlayerGrace(room, nowMs, events);
      _sweepEmptyRoomTtl(room, nowMs, events);
    }
    _sweepRateCounters(nowMs);
    return events;
  }

  /// Returns the live room with [code], or `null`.
  Room? roomByCode(String code) => _rooms[code];

  /// Number of live rooms.
  int get roomCount => _rooms.length;

  /// Identities currently tracked by the rate limiter (observable for
  /// tests and ops; pruned by [sweep] once a window goes idle).
  Set<RateIdentity> get trackedRateIdentities =>
      _rateCounters.keys.toSet();

  /// Adds a fresh seat for a player entering (or re-entering past
  /// grace) [room]; spectators only while a match runs.
  RejoinRoomStatus _enterRoom(
    Room room,
    ConnectionId connectionId,
    PlayerId playerId,
    String nickname,
    int nowMs,
  ) {
    if (room.players.length >= roomSeatCapacity) {
      return RejoinRoomStatus.roomFull;
    }
    final inMatch = room.phase == RoomPhase.inMatch;
    room.players[connectionId] = PlayerSeat(
      playerId: playerId,
      nickname: nickname,
      isSpectator: inMatch,
    );
    _roomOfConnection[connectionId] = room.code;
    room.lastOccupiedAtMs = nowMs;
    return inMatch ? RejoinRoomStatus.matchForfeit : RejoinRoomStatus.ok;
  }

  /// Generates codes until one is unused (network doc § 8).
  String _freeCode() {
    String code;
    do {
      code = generateRoomCode(_codeRandom);
    } while (_rooms.containsKey(code));
    return code;
  }

  /// Returns the room seating [connectionId], or `null`.
  Room? _roomOf(ConnectionId connectionId) {
    final code = _roomOfConnection[connectionId];
    return code == null ? null : _rooms[code];
  }

  /// Drops one seat and its connection mapping.
  void _removeSeat(Room room, ConnectionId connectionId) {
    room.players.remove(connectionId);
    if (_roomOfConnection[connectionId] == room.code) {
      _roomOfConnection.remove(connectionId);
    }
  }

  /// Deletes a room, its connection mappings, and frees its code for
  /// recycling (network doc § 8).
  void _deleteRoom(Room room) {
    for (final connectionId in room.players.keys) {
      _roomOfConnection.remove(connectionId);
    }
    _rooms.remove(room.code);
  }

  /// Closes the room when the host grace window elapsed.
  bool _sweepHostGrace(Room room, int nowMs, List<SweepEvent> events) {
    final hostSeat = room.players[room.hostConnectionId];
    final expired = hostSeat != null &&
        !hostSeat.connected &&
        nowMs - hostSeat.disconnectedAtMs! >= graceWindowMs;
    if (!expired) return false;
    events.add(HostGraceExpired(room.code));
    _deleteRoom(room);
    return true;
  }

  /// Removes reserved seats whose grace window elapsed.
  void _sweepPlayerGrace(Room room, int nowMs, List<SweepEvent> events) {
    for (final entry in room.players.entries.toList()) {
      final seat = entry.value;
      if (seat.connected) continue;
      if (nowMs - seat.disconnectedAtMs! < graceWindowMs) continue;
      final forfeited = room.phase == RoomPhase.inMatch && !seat.isSpectator;
      events.add(
        PlayerGraceExpired(
          room.code,
          playerId: seat.playerId,
          forfeited: forfeited,
        ),
      );
      _removeSeat(room, entry.key);
    }
  }

  /// Deletes long-empty rooms (network doc § 8).
  void _sweepEmptyRoomTtl(Room room, int nowMs, List<SweepEvent> events) {
    if (room.isOccupied) return;
    if (nowMs - room.lastOccupiedAtMs < emptyRoomTtlMs) return;
    events.add(EmptyRoomExpired(room.code));
    _deleteRoom(room);
  }

  /// Drops rate counters idle for a full window.
  void _sweepRateCounters(int nowMs) {
    _rateCounters.removeWhere((_, counters) {
      _prune(counters.joinAttempts, nowMs);
      _prune(counters.createAttempts, nowMs);
      return counters.joinAttempts.isEmpty && counters.createAttempts.isEmpty;
    });
  }

  /// Returns (and lazily creates) the counters for [identity].
  _RateCounters _counters(RateIdentity identity) =>
      _rateCounters.putIfAbsent(identity, _RateCounters.new);

  /// Sliding-window admission: prunes expired entries, allows and
  /// records the attempt while under [limit].
  bool _record(List<int> attempts, int limit, int nowMs) {
    _prune(attempts, nowMs);
    if (attempts.length >= limit) return false;
    attempts.add(nowMs);
    return true;
  }

  /// Keeps only attempts strictly inside the last rate window.
  void _prune(List<int> attempts, int nowMs) {
    attempts.removeWhere((t) => t <= nowMs - rateWindowMs);
  }
}
