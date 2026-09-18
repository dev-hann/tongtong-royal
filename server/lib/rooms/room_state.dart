/// Match lifecycle phases the server is aware of.
///
/// The server tracks seat logistics only. Round-level states
/// (ROUND_INTRO / ROUND_PLAY / ...) belong to `shared/domain` and are
/// opaque to the server (architecture doc § 1).
enum RoomPhase {
  /// Waiting in lobby; players can ready up.
  lobby,

  /// A match is running; new joins become spectators (network § 8).
  inMatch,
}

/// One seat reservation in a [Room], keyed by connection id.
///
/// Grace seat reservation (network doc § 5.2): when a player's socket
/// closes, the seat stays in the room with [connected] set to `false`
/// and [disconnectedAtMs] stamped, until the grace window expires or
/// the player rejoins.
final class PlayerSeat {
  /// Creates an occupied seat.
  PlayerSeat({
    required this.playerId,
    required this.nickname,
    this.isSpectator = false,
  });

  /// Stable identity of the seated player (from the handshake).
  final String playerId;

  /// Display name chosen at handshake time.
  final String nickname;

  /// Spectator seats exist only while [Room.phase] is
  /// [RoomPhase.inMatch] (network doc § 8); they become regular seats
  /// when the room returns to lobby.
  bool isSpectator;

  /// Ready flag for lobby phase; reset when a match ends.
  bool ready = false;

  /// Whether the owning socket is currently open.
  bool connected = true;

  /// When [connected] became `false`; `null` while connected.
  int? disconnectedAtMs;

  /// Whether this seat is a disconnected-but-reserved grace seat.
  bool get isReserved => !connected;
}

/// Server-side room state: code, seats, phase, timing bookkeeping.
///
/// Mutation contract: fields are public for reads by the adapter and
/// tests, but must only be mutated through `RoomManager`. All times
/// come from the injected clock (see `Clock`).
final class Room {
  /// Creates a room occupied only by its host.
  Room({
    required this.code,
    required this.hostConnectionId,
    required this.createdAtMs,
  }) : lastOccupiedAtMs = createdAtMs;

  /// Invite code; unique among live rooms. Recycled after deletion.
  final String code;

  /// Connection id of the hosting player. Rebound when the host
  /// rejoins on a new connection within grace.
  String hostConnectionId;

  /// Room creation time (ms since epoch, injected clock).
  final int createdAtMs;

  /// Time of the last membership event (create/join/rejoin/leave/
  /// disconnect). Anchor for the 5-minute empty-room TTL (net § 8).
  int lastOccupiedAtMs;

  /// Current match phase.
  RoomPhase phase = RoomPhase.lobby;

  /// Opaque round counter relayed from host transitions; the server
  /// never interprets this value.
  int roundIndex = 0;

  /// Seats keyed by connection id. Reserved (disconnected) seats keep
  /// their stale connection key until rejoin rebinds them or grace
  /// expiry removes them.
  final Map<String, PlayerSeat> players = {};

  /// Returns the seat owned by [playerId], or `null`.
  PlayerSeat? seatOfPlayer(String playerId) {
    for (final seat in players.values) {
      if (seat.playerId == playerId) return seat;
    }
    return null;
  }

  /// Returns the connection key holding [seat], or `null`.
  String? connectionOfSeat(PlayerSeat seat) {
    for (final entry in players.entries) {
      if (identical(entry.value, seat)) return entry.key;
    }
    return null;
  }

  /// Whether any seat currently has an open socket.
  bool get isOccupied =>
      players.values.any((PlayerSeat seat) => seat.connected);
}
