import 'package:flutter/foundation.dart' show immutable;
import 'package:tongtong_shared/tongtong_shared.dart';

/// Lifecycle state of a NetClient connection (network doc § 5).
///
/// The progression under normal use:
/// `disconnected → connecting → connected → joined(code)`; transport loss
/// moves the client to `reconnecting` while the grace window allows a
/// rejoin; terminal states are [NetClosed] and [NetVersionMismatch].
sealed class NetConnectionState {
  /// Base constructor for states.
  const NetConnectionState();
}

/// No connection and no reconnect in progress.
@immutable
final class NetDisconnected extends NetConnectionState {
  /// Creates the idle state, optionally carrying the last failure reason.
  const NetDisconnected({this.lastError});

  /// Human-readable last failure, if any.
  final String? lastError;

  @override
  bool operator ==(Object other) =>
      other is NetDisconnected && other.lastError == lastError;

  @override
  int get hashCode => Object.hash(NetDisconnected, lastError);

  @override
  String toString() => 'NetDisconnected(lastError: $lastError)';
}

/// A connection attempt is in flight.
@immutable
final class NetConnecting extends NetConnectionState {
  /// Creates the state.
  const NetConnecting();

  @override
  bool operator ==(Object other) => other is NetConnecting;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'NetConnecting()';
}

/// Socket open and handshake (`Hello`) accepted by the server.
@immutable
final class NetConnected extends NetConnectionState {
  /// Creates the state.
  const NetConnected();

  @override
  bool operator ==(Object other) => other is NetConnected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'NetConnected()';
}

/// Joined to a room; [roomCode] identifies it.
@immutable
final class NetJoined extends NetConnectionState {
  /// Creates the state for the room with [roomCode].
  const NetJoined({required this.roomCode});

  /// Six-character uppercase invite code of the joined room.
  final String roomCode;

  @override
  bool operator ==(Object other) =>
      other is NetJoined && other.roomCode == roomCode;

  @override
  int get hashCode => Object.hash(NetJoined, roomCode);

  @override
  String toString() => 'NetJoined($roomCode)';
}

/// Transport lost; automatic rejoin attempts run while grace allows
/// (network doc § 5). [attempt] is 0 while backgrounded, otherwise the
/// 1-based backoff attempt number.
@immutable
final class NetReconnecting extends NetConnectionState {
  /// Creates the state.
  const NetReconnecting({required this.roomCode, required this.attempt});

  /// Room to rejoin once the socket is back, `null` if none was joined.
  final String? roomCode;

  /// 1-based reconnect attempt about to run (0 = waiting for resume).
  final int attempt;

  @override
  bool operator ==(Object other) =>
      other is NetReconnecting &&
      other.roomCode == roomCode &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(NetReconnecting, roomCode, attempt);

  @override
  String toString() => 'NetReconnecting($roomCode, attempt: $attempt)';
}

/// Terminal: the connection is down and will not recover by itself.
@immutable
final class NetClosed extends NetConnectionState {
  /// Creates the state.
  const NetClosed({required this.needsManualRejoin, this.roomCloseReason});

  /// True when the room may still exist server-side and the user can
  /// trigger `rejoinRoom` manually (grace expired, reconnect budget
  /// exhausted).
  final bool needsManualRejoin;

  /// Server-side reason when the room itself ended, `null` otherwise.
  final RoomCloseReason? roomCloseReason;

  @override
  bool operator ==(Object other) =>
      other is NetClosed &&
      other.needsManualRejoin == needsManualRejoin &&
      other.roomCloseReason == roomCloseReason;

  @override
  int get hashCode =>
      Object.hash(NetClosed, needsManualRejoin, roomCloseReason);

  @override
  String toString() =>
      'NetClosed(needsManualRejoin: $needsManualRejoin, '
      'roomCloseReason: $roomCloseReason)';
}

/// Terminal: the server rejected the handshake on protocol version
/// grounds (network doc § 2). Never retried automatically.
@immutable
final class NetVersionMismatch extends NetConnectionState {
  /// Creates the state from the server's verdict.
  const NetVersionMismatch({required this.status});

  /// Which side is outdated.
  final VersionStatus status;

  @override
  bool operator ==(Object other) =>
      other is NetVersionMismatch && other.status == status;

  @override
  int get hashCode => Object.hash(NetVersionMismatch, status);

  @override
  String toString() => 'NetVersionMismatch($status)';
}

/// Immutable, UI-facing snapshot of the network layer (network doc § 6).
///
/// Presentation renders this; it contains no rules and no behavior.
@immutable
final class NetStatus {
  /// Creates the status.
  const NetStatus({
    required this.state,
    this.ping,
    this.unstable = false,
    this.lastError,
  });

  /// Current connection lifecycle state.
  final NetConnectionState state;

  /// Round-trip time of the last completed ping, if any.
  final Duration? ping;

  /// True while snapshots are starving during an active match
  /// (network doc § 6: no snapshot for 2 s).
  final bool unstable;

  /// Human-readable last error, if any.
  final String? lastError;

  @override
  bool operator ==(Object other) =>
      other is NetStatus &&
      other.state == state &&
      other.ping == ping &&
      other.unstable == unstable &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(NetStatus, state, ping, unstable,
      lastError);

  @override
  String toString() =>
      'NetStatus($state, ping: $ping, unstable: $unstable, '
      'lastError: $lastError)';
}
