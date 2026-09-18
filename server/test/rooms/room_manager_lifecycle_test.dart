import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('net_8 empty-room TTL', () {
    test('room deleted and code recycled 5 min after last leave', () {
      final random = SequencedRandom([0]);
      final m = makeManager(random: random);
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      // Both humans leave; last leave anchors the TTL.
      expect(m.manager.leaveRoom('p2-conn'), LeaveRoomStatus.left);
      expect(m.manager.leaveRoom('host-conn'), LeaveRoomStatus.left);
      expect(m.manager.roomCount, 1);

      final events = m.manager.sweep(301000);

      expect(
        events,
        contains(isA<EmptyRoomExpired>().having(
          (e) => e.roomCode,
          'roomCode',
          code,
        )),
      );
      expect(m.manager.roomCount, 0);

      // Code was recycled: next create reuses it.
      final recycled = m.manager.createRoom(
        connectionId: 'c9',
        playerId: 'p9',
        nickname: 'P9',
        identity: 'ip-9',
      );
      expect(recycled.roomCode, code);
    });

    test('TTL does not fire one millisecond early', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.leaveRoom('host-conn');

      expect(m.manager.sweep(300999), isEmpty);
      expect(m.manager.roomByCode(code), isNotNull);
    });

    test('occupied room is never swept by TTL', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.clock.advanceMs(3600000);

      expect(m.manager.sweep(m.clock()), isEmpty);
      expect(m.manager.roomByCode(code), isNotNull);
    });

    test('sweep is idempotent: second sweep emits nothing', () {
      final m = makeManager();
      hostRoom(m.manager);
      m.manager.leaveRoom('host-conn');
      expect(m.manager.sweep(301000), isNotEmpty);
      expect(m.manager.sweep(301000), isEmpty);
    });
  });

  group('leaveRoom', () {
    test('player leaves immediately; match continues without seat', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);

      expect(m.manager.leaveRoom('p2-conn'), LeaveRoomStatus.left);

      final room = m.manager.roomByCode(code)!;
      expect(room.players, isNot(contains('p2-conn')));
      expect(room.phase, RoomPhase.inMatch);
    });

    test('host leaving with players present closes room as hostLeft', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(m.manager.leaveRoom('host-conn'), LeaveRoomStatus.roomClosed);
      expect(m.manager.roomCount, 0);
      expect(m.manager.leaveRoom('p2-conn'), LeaveRoomStatus.notInRoom);
    });

    test('unknown connection yields notInRoom', () {
      final m = makeManager();
      expect(m.manager.leaveRoom('ghost'), LeaveRoomStatus.notInRoom);
    });

    test('lastOccupiedAtMs updates on leave', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.clock.advanceMs(2000);
      m.manager.leaveRoom('host-conn');
      expect(m.manager.roomByCode(code)!.lastOccupiedAtMs, 3000);
    });

    test('lastOccupiedAtMs updates on disconnect', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.clock.advanceMs(7000);
      m.manager.disconnect('host-conn');
      expect(m.manager.roomByCode(code)!.lastOccupiedAtMs, 8000);
    });
  });
}
