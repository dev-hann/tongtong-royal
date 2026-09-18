import 'dart:math';

import 'package:tongtong_server/tongtong_server.dart';

/// Random stub that replays a cyclic `nextInt` sequence; used to
/// force invite-code collisions deterministically in manager tests.
class SequencedRandom implements Random {
  /// Creates a stub replaying [values] forever.
  SequencedRandom(this.values);

  /// Values returned by [nextInt], cycled in order.
  final List<int> values;

  int _cursor = 0;

  @override
  int nextInt(int max) {
    final value = values[_cursor % values.length];
    _cursor++;
    return value % max;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// A manager paired with its manual clock, for stepping time in tests.
typedef Managed = ({RoomManager manager, ManualClock clock});

/// Builds a [RoomManager] driven by a [ManualClock] at [startMs].
Managed makeManager({
  int startMs = 1000,
  Random? random,
  int maxRooms = defaultMaxRooms,
}) {
  final clock = ManualClock(startMs: startMs);
  final manager = RoomManager(
    clock: clock.call,
    codeRandom: random,
    maxRooms: maxRooms,
  );
  return (manager: manager, clock: clock);
}

/// Creates a room hosted by `host-conn` and returns its code.
String hostRoom(RoomManager manager) {
  final result = manager.createRoom(
    connectionId: 'host-conn',
    playerId: 'host',
    nickname: 'Host',
    identity: 'ip-host',
  );
  return result.roomCode;
}

/// Creates a two-player room, readies both players, starts the match,
/// and returns the room code (phase becomes `inMatch`).
String activeMatchRoom(RoomManager manager) {
  final code = hostRoom(manager);
  manager
    ..joinRoom(
      code: code,
      connectionId: 'p2-conn',
      playerId: 'p2',
      nickname: 'Player2',
      identity: 'ip-p2',
    )
    ..setReady(connectionId: 'host-conn', ready: true)
    ..setReady(connectionId: 'p2-conn', ready: true)
    ..startMatch('host-conn');
  return code;
}
