import 'dart:math';

import 'package:test/test.dart';

import 'test_support.dart';

void main() {
  group('injected clock determinism', () {
    test('same seed and clock schedule produce identical state', () {
      final rooms = <(String, Managed)>[];
      for (var i = 0; i < 2; i++) {
        final m = makeManager(random: Random(1234));
        final code = hostRoom(m.manager);
        m.manager.joinRoom(
          code: code,
          connectionId: 'p2-conn',
          playerId: 'p2',
          nickname: 'P2',
          identity: 'ip-2',
        );
        m.clock.advanceMs(2500);
        m.manager.disconnect('p2-conn');
        m.clock.advanceMs(7500);
        rooms.add((code, m));
      }

      final (codeA, a) = rooms[0];
      final (codeB, b) = rooms[1];
      expect(codeA, codeB);

      final roomA = a.manager.roomByCode(codeA)!;
      final roomB = b.manager.roomByCode(codeB)!;
      expect(roomA.createdAtMs, roomB.createdAtMs);
      expect(roomA.lastOccupiedAtMs, roomB.lastOccupiedAtMs);
      expect(
        roomA.players['p2-conn']!.disconnectedAtMs,
        roomB.players['p2-conn']!.disconnectedAtMs,
      );

      final eventsA = a.manager.sweep(11000);
      final eventsB = b.manager.sweep(11000);
      expect(
        eventsA.map((e) => (e.roomCode, e.runtimeType)).toList(),
        eventsB.map((e) => (e.roomCode, e.runtimeType)).toList(),
      );
    });

    test('timestamps equal injected clock values, never wall time', () {
      // Real wall time is ~1.7e12 ms; injected values stay tiny, so
      // equality proves the clock is the only time source.
      final m = makeManager(startMs: 1234);
      final result = m.manager.createRoom(
        connectionId: 'c1',
        playerId: 'p1',
        nickname: 'P1',
        identity: 'ip-1',
      );
      final room = m.manager.roomByCode(result.roomCode)!;
      expect(room.createdAtMs, 1234);

      m.clock.advanceMs(4321);
      m.manager.disconnect('c1');
      expect(room.players['c1']!.disconnectedAtMs, 5555);
    });
  });
}
