part of 'messages.dart';

/// Rejects a handshake due to protocol version mismatch (network doc § 2).
@immutable
final class VersionMismatch extends WireMessage {
  /// Creates the rejection.
  const VersionMismatch({required this.status});

  /// Which side is outdated.
  final VersionStatus status;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'status': status.name};

  @override
  bool operator ==(Object other) =>
      other is VersionMismatch && other.status == status;

  @override
  int get hashCode => Object.hash(VersionMismatch, status);
}

/// Join/rejoin rate limit exceeded (network doc § 5.4); connection dropped.
@immutable
final class RateLimited extends WireMessage {
  /// Creates the notice.
  const RateLimited();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is RateLimited;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Same playerId already has an open socket; first socket wins
/// (network doc § 6).
@immutable
final class AlreadyConnected extends WireMessage {
  /// Creates the notice.
  const AlreadyConnected();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is AlreadyConnected;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Server is at its concurrent room limit (network doc § 8).
@immutable
final class ServerFull extends WireMessage {
  /// Creates the notice.
  const ServerFull();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is ServerFull;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Lobby entry of one player inside a [RoomSnapshot].
@immutable
final class PlayerInfo {
  /// Creates the entry.
  const PlayerInfo({
    required this.playerId,
    required this.nickname,
    required this.ready,
  });

  /// Identity of the player.
  final PlayerId playerId;

  /// Display name of the player.
  final String nickname;

  /// Lobby ready flag.
  final bool ready;

  /// Wire form of this entry.
  Map<String, Object?> toJson() => <String, Object?>{
    'playerId': playerId,
    'nickname': nickname,
    'ready': ready,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerInfo &&
      other.playerId == playerId &&
      other.nickname == nickname &&
      other.ready == ready;

  @override
  int get hashCode => Object.hash(PlayerInfo, playerId, nickname, ready);
}

/// Full room state reply sent after join/create/rejoin and on changes
/// while in the lobby (network doc § 2).
@immutable
final class RoomSnapshot extends WireMessage {
  /// Creates the snapshot.
  const RoomSnapshot({
    required this.code,
    required this.players,
    required this.phase,
    required this.roundIndex,
  });

  /// Room invite code.
  final String code;

  /// Players currently in the room.
  final List<PlayerInfo> players;

  /// Current room phase (domain `RoundPhase`).
  final RoundPhase phase;

  /// Zero-based round index, valid once a match started.
  final int roundIndex;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'players': players.map((p) => p.toJson()).toList(),
    'phase': phase.name,
    'roundIndex': roundIndex,
  };

  @override
  bool operator ==(Object other) =>
      other is RoomSnapshot &&
      other.code == code &&
      _listEquals(other.players, players) &&
      other.phase == phase &&
      other.roundIndex == roundIndex;

  @override
  int get hashCode => Object.hash(RoomSnapshot, code, phase, roundIndex);
}

/// Broadcast at `ROUND_INTRO`: everything clients need to build the map
/// (network doc § 4).
@immutable
final class RoundStarting extends WireMessage {
  /// Creates the announcement.
  const RoundStarting({
    required this.roundIndex,
    required this.minigameId,
    required this.mapSeed,
    required this.timeoutMs,
  });

  /// Zero-based index of the round inside the match.
  final int roundIndex;

  /// Which minigame to build.
  final MiniGameId minigameId;

  /// Seed selecting the map variant; layout data never crosses the wire.
  final int mapSeed;

  /// Round timeout in milliseconds, owned by the host.
  final int timeoutMs;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'roundIndex': roundIndex,
    'minigameId': minigameId,
    'mapSeed': mapSeed,
    'timeoutMs': timeoutMs,
  };

  @override
  bool operator ==(Object other) =>
      other is RoundStarting &&
      other.roundIndex == roundIndex &&
      other.minigameId == minigameId &&
      other.mapSeed == mapSeed &&
      other.timeoutMs == timeoutMs;

  @override
  int get hashCode => Object.hash(
        RoundStarting,
        roundIndex,
        minigameId,
        mapSeed,
        timeoutMs,
      );
}

/// Per-player simulation state inside a 20 Hz host [Snapshot]
/// (network doc § 1).
///
/// Precision: `x`, `y`, `angle`, `vx`, `vy` are quantized to **2 decimal
/// places** at the protocol boundary via `toStringAsFixed` parsing
/// (network doc § 7); non-finite values collapse to `0.0`. World scale is
/// 1 unit = 1 meter, so 2 decimals ≈ 1 cm resolution — finer than any
/// renderer at these camera zooms.
@immutable
final class PlayerState {
  /// Creates the state; values are stored as given and quantized only
  /// when serialized.
  const PlayerState({
    required this.playerId,
    required this.x,
    required this.y,
    required this.angle,
    required this.vx,
    required this.vy,
  });

  /// Identity of the player.
  final PlayerId playerId;

  /// Position X in meters.
  final double x;

  /// Position Y in meters.
  final double y;

  /// Body rotation in radians.
  final double angle;

  /// Linear velocity X in m/s.
  final double vx;

  /// Linear velocity Y in m/s.
  final double vy;

  /// Wire form with quantized numbers.
  Map<String, Object?> toJson() => <String, Object?>{
    'playerId': playerId,
    'x': quantize(x),
    'y': quantize(y),
    'angle': quantize(angle),
    'vx': quantize(vx),
    'vy': quantize(vy),
  };

  /// Quantizes [v] to 2 decimals for the wire; non-finite → 0.
  static double quantize(double v) {
    if (!v.isFinite) {
      return 0;
    }
    return double.parse(v.toStringAsFixed(2));
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.playerId == playerId &&
      other.x == x &&
      other.y == y &&
      other.angle == angle &&
      other.vx == vx &&
      other.vy == vy;

  @override
  int get hashCode =>
      Object.hash(PlayerState, playerId, x, y, angle, vx, vy);
}

/// Host-authoritative world state broadcast at 20 Hz (network doc § 1).
@immutable
final class Snapshot extends WireMessage {
  /// Creates the snapshot.
  const Snapshot({required this.tick, required this.players});

  /// Host global tick; snapshots with tick ≤ last applied are dropped.
  final int tick;

  /// State of every player (≤ 4).
  final List<PlayerState> players;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'tick': tick,
    'players': players.map((p) => p.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is Snapshot &&
      other.tick == tick &&
      _listEquals(other.players, players);

  @override
  int get hashCode => Object.hash(Snapshot, tick);
}

/// Relayed domain judging result for one finished round. Reuses the
/// domain `RoundResult` type; only the host judges (network doc § 3).
@immutable
final class RoundResultsMessage extends WireMessage {
  /// Creates the message.
  const RoundResultsMessage({required this.roundResult});

  /// Domain-resolved standings of the finished round.
  final RoundResult roundResult;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'roundResult': <String, Object?>{
      'roundIndex': roundResult.roundIndex,
      'minigameId': roundResult.minigameId,
      'placements': roundResult.placements
          .map(
            (p) => <String, Object?>{
              'playerId': p.playerId,
              'rank': p.rank,
              'points': p.points,
            },
          )
          .toList(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is RoundResultsMessage &&
      other.roundResult.roundIndex == roundResult.roundIndex &&
      other.roundResult.minigameId == roundResult.minigameId &&
      _listEquals(other.roundResult.placements, roundResult.placements);

  @override
  int get hashCode =>
      Object.hash(RoundResultsMessage, roundResult.roundIndex);
}

/// Why a room ended (network doc § 5.1, § 8).
enum RoomCloseReason {
  /// Host left and the grace window expired.
  hostLeft,

  /// Server drain shutdown.
  serverShutdown,

  /// Room went empty and the TTL expired.
  empty,
}

/// Tells clients the room no longer exists.
@immutable
final class RoomClosed extends WireMessage {
  /// Creates the notice.
  const RoomClosed({required this.reason});

  /// Why the room ended.
  final RoomCloseReason reason;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'reason': reason.name};

  @override
  bool operator ==(Object other) =>
      other is RoomClosed && other.reason == reason;

  @override
  int get hashCode => Object.hash(RoomClosed, reason);
}

/// Connection keepalive, client → server.
@immutable
final class Ping extends WireMessage {
  /// Creates the probe.
  const Ping();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is Ping;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Connection keepalive reply, server → client.
@immutable
final class Pong extends WireMessage {
  /// Creates the reply.
  const Pong();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is Pong;

  @override
  int get hashCode => runtimeType.hashCode;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
