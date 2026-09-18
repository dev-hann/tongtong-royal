import 'dart:convert';

import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/round_state_machine.dart';
import 'package:tongtong_shared/src/protocol/messages.dart';
import 'package:tongtong_shared/src/protocol/protocol_version.dart';

/// Hard cap on a serialized message: 4 KB UTF-8 bytes (network doc § 6).
/// Sockets delivering over-cap messages are disconnected by the server.
const int maxMessageBytes = 4096;

/// Thrown when a message cannot be decoded or is too large. Callers must
/// catch this, drop the message and log — never crash (network doc § 9).
final class ProtocolException implements Exception {
  /// Creates the exception with a human-readable [reason].
  const ProtocolException(this.reason);

  /// Why the message was rejected.
  final String reason;

  @override
  String toString() => 'ProtocolException: $reason';
}

/// Stable tag table — one wire tag per message type.
///
/// Tags are part of the wire contract: never rename, never reuse a tag
/// for a different meaning. Breaking changes bump `protocolVersion`.
///
/// | Tag               | Type                 | Direction |
/// |-------------------|----------------------|-----------|
/// | `hello`           | [Hello]              | C → S     |
/// | `create_room`     | [CreateRoom]         | C → S     |
/// | `join_room`       | [JoinRoom]           | C → S     |
/// | `rejoin_room`     | [RejoinRoom]         | C → S     |
/// | `leave_room`      | [LeaveRoom]          | C → S     |
/// | `set_ready`       | [SetReady]           | C → S     |
/// | `start_match`     | [StartMatch]         | C → S     |
/// | `end_match`       | [EndMatch]           | C → S     |
/// | `input`           | [PlayerInputMessage] | C → S     |
/// | `version_mismatch`| [VersionMismatch]    | S → C     |
/// | `rate_limited`    | [RateLimited]        | S → C     |
/// | `already_connected`| [AlreadyConnected]  | S → C     |
/// | `server_full`     | [ServerFull]         | S → C     |
/// | `join_failed`     | [JoinFailed]         | S → C     |
/// | `room_snapshot`   | [RoomSnapshot]       | S → C     |
/// | `round_starting`  | [RoundStarting]      | S → C     |
/// | `snapshot`        | [Snapshot]           | S → C     |
/// | `round_results`   | [RoundResultsMessage]| S → C     |
/// | `room_closed`     | [RoomClosed]         | S → C     |
/// | `ping`            | [Ping]               | C → S     |
/// | `pong`            | [Pong]               | S → C     |
const Map<Type, String> messageTags = <Type, String>{
  Hello: 'hello',
  CreateRoom: 'create_room',
  JoinRoom: 'join_room',
  RejoinRoom: 'rejoin_room',
  LeaveRoom: 'leave_room',
  SetReady: 'set_ready',
  StartMatch: 'start_match',
  EndMatch: 'end_match',
  PlayerInputMessage: 'input',
  VersionMismatch: 'version_mismatch',
  RateLimited: 'rate_limited',
  AlreadyConnected: 'already_connected',
  ServerFull: 'server_full',
  JoinFailed: 'join_failed',
  RoomSnapshot: 'room_snapshot',
  RoundStarting: 'round_starting',
  Snapshot: 'snapshot',
  RoundResultsMessage: 'round_results',
  RoomClosed: 'room_closed',
  Ping: 'ping',
  Pong: 'pong',
};

/// Tag → payload decoder. Exposed so tests can assert the tag table is
/// complete and consistent.
const Map<String, WireMessage Function(Map<String, dynamic>)> messageDecoders =
    <String, WireMessage Function(Map<String, dynamic>)>{
      'hello': _decodeHello,
      'create_room': _decodeCreateRoom,
      'join_room': _decodeJoinRoom,
      'rejoin_room': _decodeRejoinRoom,
      'leave_room': _decodeLeaveRoom,
      'set_ready': _decodeSetReady,
      'start_match': _decodeStartMatch,
      'end_match': _decodeEndMatch,
      'input': _decodeInput,
      'version_mismatch': _decodeVersionMismatch,
      'rate_limited': _decodeRateLimited,
      'already_connected': _decodeAlreadyConnected,
      'server_full': _decodeServerFull,
      'join_failed': _decodeJoinFailed,
      'room_snapshot': _decodeRoomSnapshot,
      'round_starting': _decodeRoundStarting,
      'snapshot': _decodeSnapshot,
      'round_results': _decodeRoundResults,
      'room_closed': _decodeRoomClosed,
      'ping': _decodePing,
      'pong': _decodePong,
    };

/// Encodes [msg] into the envelope `{"t": <tag>, "v": <payload>}`.
///
/// Throws [ProtocolException] if [msg] has no registered tag or the
/// encoded form exceeds [maxMessageBytes].
String encode(WireMessage msg) {
  final tag = messageTags[msg.runtimeType];
  if (tag == null) {
    throw ProtocolException('no wire tag registered for ${msg.runtimeType}');
  }
  final String json;
  try {
    json = jsonEncode(<String, Object?>{'t': tag, 'v': msg.toJson()});
  } on FormatException catch (e) {
    throw ProtocolException('encoding failed: ${e.message}');
  }
  assertSize(json);
  return json;
}

/// Decodes an envelope produced by [encode]. Throws [ProtocolException]
/// on malformed JSON, wrong envelope shape, unknown tags, missing fields,
/// wrong field types or unknown enum values — never any other exception
/// type.
WireMessage decode(String json) {
  Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException catch (e) {
    throw ProtocolException('malformed JSON: ${e.message}');
  }
  if (data is! Map<String, dynamic>) {
    throw const ProtocolException('envelope must be a JSON object');
  }
  final tag = data['t'];
  if (tag is! String) {
    throw const ProtocolException('envelope field "t" must be a string');
  }
  final payload = data['v'];
  if (payload is! Map<String, dynamic>) {
    throw const ProtocolException('envelope field "v" must be an object');
  }
  final decoder = messageDecoders[tag];
  if (decoder == null) {
    throw ProtocolException('unknown tag "$tag"');
  }
  return decoder(payload);
}

/// Throws [ProtocolException] when [encoded] exceeds [maxMessageBytes]
/// UTF-8 bytes (network doc § 6).
void assertSize(String encoded) {
  final bytes = utf8.encode(encoded).length;
  if (bytes > maxMessageBytes) {
    throw ProtocolException(
      'message is $bytes bytes, over the $maxMessageBytes-byte cap',
    );
  }
}

Never _fail(String reason) => throw ProtocolException(reason);

String _reqString(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! String) {
    _fail('field "$field" must be a string');
  }
  return value;
}

int _reqInt(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! int) {
    _fail('field "$field" must be an integer');
  }
  return value;
}

double _reqDouble(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! num) {
    _fail('field "$field" must be a number');
  }
  return value.toDouble();
}

bool _reqBool(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! bool) {
    _fail('field "$field" must be a boolean');
  }
  return value;
}

/// Optional boolean with a default; absent key → [fallback]. Used for
/// wire-compatible additions whose old payloads lack the key.
bool _optBool(Map<String, dynamic> v, String field, bool fallback) {
  if (!v.containsKey(field)) {
    return fallback;
  }
  return _reqBool(v, field);
}

/// Optional string; absent key → `null`. Used for wire-compatible
/// additions whose old payloads lack the key.
String? _optString(Map<String, dynamic> v, String field) {
  if (!v.containsKey(field)) {
    return null;
  }
  return _reqString(v, field);
}

List<dynamic> _reqList(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! List) {
    _fail('field "$field" must be a list');
  }
  return value;
}

Map<String, dynamic> _reqMap(Map<String, dynamic> v, String field) {
  final value = v[field];
  if (value is! Map) {
    _fail('field "$field" must be an object');
  }
  return Map<String, dynamic>.from(value);
}

T _reqEnum<T extends Enum>(
  Map<String, dynamic> v,
  String field,
  List<T> values,
) {
  final name = _reqString(v, field);
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  _fail('field "$field": unknown value "$name"');
}

WireMessage _decodeHello(Map<String, dynamic> v) => Hello(
  protocolVersion: _reqInt(v, 'protocolVersion'),
  playerId: _reqString(v, 'playerId'),
  nickname: _reqString(v, 'nickname'),
);

WireMessage _decodeJoinRoom(Map<String, dynamic> v) =>
    JoinRoom(code: _reqString(v, 'code'));

WireMessage _decodeRejoinRoom(Map<String, dynamic> v) =>
    RejoinRoom(code: _reqString(v, 'code'));

WireMessage _decodeSetReady(Map<String, dynamic> v) =>
    SetReady(ready: _reqBool(v, 'ready'));

WireMessage _decodeInput(Map<String, dynamic> v) => PlayerInputMessage(
  seq: _reqInt(v, 'seq'),
  moveX: _reqDouble(v, 'moveX'),
  moveY: _reqDouble(v, 'moveY'),
  jump: _reqBool(v, 'jump'),
  dash: _reqBool(v, 'dash'),
  playerId: _optString(v, 'playerId'),
);

WireMessage _decodeVersionMismatch(Map<String, dynamic> v) =>
    VersionMismatch(status: _reqEnum(v, 'status', VersionStatus.values));

WireMessage _decodeRoomSnapshot(Map<String, dynamic> v) => RoomSnapshot(
  code: _reqString(v, 'code'),
  players: _reqList(
    v,
    'players',
  ).map((e) => _decodePlayerInfo(_asMap(e, 'players'))).toList(),
  phase: _reqEnum(v, 'phase', RoundPhase.values),
  roundIndex: _reqInt(v, 'roundIndex'),
);

PlayerInfo _decodePlayerInfo(Map<String, dynamic> v) => PlayerInfo(
  playerId: _reqString(v, 'playerId'),
  nickname: _reqString(v, 'nickname'),
  ready: _reqBool(v, 'ready'),
  connected: _optBool(v, 'connected', true),
  isSpectator: _optBool(v, 'isSpectator', false),
);

WireMessage _decodeRoundStarting(Map<String, dynamic> v) => RoundStarting(
  roundIndex: _reqInt(v, 'roundIndex'),
  minigameId: _reqString(v, 'minigameId'),
  mapSeed: _reqInt(v, 'mapSeed'),
  timeoutMs: _reqInt(v, 'timeoutMs'),
);

WireMessage _decodeSnapshot(Map<String, dynamic> v) => Snapshot(
  tick: _reqInt(v, 'tick'),
  players: _reqList(
    v,
    'players',
  ).map((e) => _decodePlayerState(_asMap(e, 'players'))).toList(),
);

PlayerState _decodePlayerState(Map<String, dynamic> v) => PlayerState(
  playerId: _reqString(v, 'playerId'),
  x: _reqDouble(v, 'x'),
  y: _reqDouble(v, 'y'),
  angle: _reqDouble(v, 'angle'),
  vx: _reqDouble(v, 'vx'),
  vy: _reqDouble(v, 'vy'),
);

WireMessage _decodeRoundResults(Map<String, dynamic> v) {
  final r = _reqMap(v, 'roundResult');
  return RoundResultsMessage(
    roundResult: RoundResult(
      roundIndex: _reqInt(r, 'roundIndex'),
      minigameId: _reqString(r, 'minigameId'),
      placements: _reqList(
        r,
        'placements',
      ).map((e) => _decodePlacement(_asMap(e, 'placements'))).toList(),
    ),
  );
}

Placement _decodePlacement(Map<String, dynamic> v) => Placement(
  playerId: _reqString(v, 'playerId'),
  rank: _reqInt(v, 'rank'),
  points: _reqInt(v, 'points'),
);

WireMessage _decodeRoomClosed(Map<String, dynamic> v) =>
    RoomClosed(reason: _reqEnum(v, 'reason', RoomCloseReason.values));

WireMessage _decodeJoinFailed(Map<String, dynamic> v) =>
    JoinFailed(reason: _reqEnum(v, 'reason', JoinFailReason.values));

Map<String, dynamic> _asMap(Object? e, String field) {
  if (e is! Map) {
    _fail('entries of "$field" must be objects');
  }
  return Map<String, dynamic>.from(e);
}

WireMessage _decodeCreateRoom(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'create_room', const CreateRoom());

WireMessage _decodeLeaveRoom(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'leave_room', const LeaveRoom());

WireMessage _decodeStartMatch(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'start_match', const StartMatch());

WireMessage _decodeEndMatch(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'end_match', const EndMatch());

WireMessage _decodeRateLimited(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'rate_limited', const RateLimited());

WireMessage _decodeAlreadyConnected(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'already_connected', const AlreadyConnected());

WireMessage _decodeServerFull(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'server_full', const ServerFull());

WireMessage _decodePing(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'ping', const Ping());

WireMessage _decodePong(Map<String, dynamic> v) =>
    _decodeEmptyPayload(v, 'pong', const Pong());

WireMessage _decodeEmptyPayload(
  Map<String, dynamic> v,
  String tag,
  WireMessage message,
) {
  if (v.isNotEmpty) {
    _fail('tag "$tag" expects an empty payload');
  }
  return message;
}
