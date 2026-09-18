part of 'messages.dart';

/// First message on a fresh connection (network doc § 2).
@immutable
final class Hello extends WireMessage {
  /// Creates a handshake declaration.
  const Hello({
    required this.protocolVersion,
    required this.playerId,
    required this.nickname,
  });

  /// Protocol version the client speaks.
  final int protocolVersion;

  /// Client-generated UUID identifying the player.
  final PlayerId playerId;

  /// Display name chosen by the player.
  final String nickname;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'protocolVersion': protocolVersion,
    'playerId': playerId,
    'nickname': nickname,
  };

  @override
  bool operator ==(Object other) =>
      other is Hello &&
      other.protocolVersion == protocolVersion &&
      other.playerId == playerId &&
      other.nickname == nickname;

  @override
  int get hashCode => Object.hash(protocolVersion, playerId, nickname);
}

/// Requests creation of a new room; server replies with a [RoomSnapshot].
@immutable
final class CreateRoom extends WireMessage {
  /// Creates the request.
  const CreateRoom();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is CreateRoom;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Requests joining the room with invite [code].
@immutable
final class JoinRoom extends WireMessage {
  /// Creates the request.
  const JoinRoom({required this.code});

  /// Six-character uppercase room invite code.
  final String code;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'code': code};

  @override
  bool operator ==(Object other) => other is JoinRoom && other.code == code;

  @override
  int get hashCode => Object.hash(JoinRoom, code);
}

/// Requests reconnecting to a room within the grace window
/// (network doc § 5).
@immutable
final class RejoinRoom extends WireMessage {
  /// Creates the request.
  const RejoinRoom({required this.code});

  /// Six-character uppercase room invite code.
  final String code;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'code': code};

  @override
  bool operator ==(Object other) => other is RejoinRoom && other.code == code;

  @override
  int get hashCode => Object.hash(RejoinRoom, code);
}

/// Leaves the current room voluntarily.
@immutable
final class LeaveRoom extends WireMessage {
  /// Creates the request.
  const LeaveRoom();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is LeaveRoom;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Toggles the sender's ready flag in the lobby.
@immutable
final class SetReady extends WireMessage {
  /// Creates the request.
  const SetReady({required this.ready});

  /// Whether the player is ready.
  final bool ready;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'ready': ready};

  @override
  bool operator ==(Object other) => other is SetReady && other.ready == ready;

  @override
  int get hashCode => Object.hash(SetReady, ready);
}

/// Host-only request to start the match from the lobby.
@immutable
final class StartMatch extends WireMessage {
  /// Creates the request.
  const StartMatch();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};

  @override
  bool operator ==(Object other) => other is StartMatch;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// One 30 Hz input sample (network doc § 1). Values are pre-sanitized by
/// `PhysicsGuards.sanitizeJoystick` on the sending side; the constructor
/// clamps defensively again so no out-of-range or non-finite value can
/// exist in an instance.
@immutable
final class PlayerInputMessage extends WireMessage {
  /// Creates an input sample. [moveX]/[moveY] are clamped to [-1, 1];
  /// NaN collapses to 0.
  PlayerInputMessage({
    required this.seq,
    required double moveX,
    required double moveY,
    required this.jump,
    required this.dash,
  })  : moveX = _sanitize(moveX),
        moveY = _sanitize(moveY);

  /// Monotonic per-connection input counter; later wins.
  final int seq;

  /// Joystick X in [-1, 1].
  final double moveX;

  /// Joystick Y in [-1, 1].
  final double moveY;

  /// Jump edge flag for this sample.
  final bool jump;

  /// Dash edge flag for this sample.
  final bool dash;

  static double _sanitize(double v) {
    if (v.isNaN) {
      return 0;
    }
    return v.clamp(-1, 1).toDouble();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'seq': seq,
    'moveX': moveX,
    'moveY': moveY,
    'jump': jump,
    'dash': dash,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerInputMessage &&
      other.seq == seq &&
      other.moveX == moveX &&
      other.moveY == moveY &&
      other.jump == jump &&
      other.dash == dash;

  @override
  int get hashCode => Object.hash(
        PlayerInputMessage,
        seq,
        moveX,
        moveY,
        jump,
        dash,
      );
}
