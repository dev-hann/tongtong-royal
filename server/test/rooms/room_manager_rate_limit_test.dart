import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('net_5_4 join/rejoin rate limit', () {
    test('10 attempts per minute allowed, 11th rateLimited', () {
      final m = makeManager();
      final code = hostRoom(m.manager);

      // 4 joins succeed, 6 hit roomFull — all 10 count as attempts.
      for (var i = 2; i <= 11; i++) {
        m.manager.joinRoom(
          code: code,
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'attacker',
        );
      }

      final eleventh = m.manager.joinRoom(
        code: code,
        connectionId: 'c99',
        playerId: 'p99',
        nickname: 'P99',
        identity: 'attacker',
      );
      expect(eleventh, JoinRoomStatus.rateLimited);
      expect(m.manager.roomByCode(code)!.players, isNot(contains('c99')));
    });

    test('rejoin attempts share the 10-per-minute budget', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.disconnect('host-conn');

      for (var i = 0; i < 10; i++) {
        m.manager.rejoinRoom(
          code: code,
          connectionId: 'attempt-$i',
          playerId: 'ghost-$i',
          nickname: 'G',
          identity: 'attacker',
        );
      }

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'over',
        playerId: 'over',
        nickname: 'G',
        identity: 'attacker',
      );
      expect(status, RejoinRoomStatus.rateLimited);
    });

    test('window resets after 60 seconds', () {
      final m = makeManager(startMs: 0);
      final code = hostRoom(m.manager);
      for (var i = 2; i <= 11; i++) {
        m.manager.joinRoom(
          code: code,
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'attacker',
        );
      }
      expect(
        m.manager.joinRoom(
          code: code,
          connectionId: 'cx',
          playerId: 'px',
          nickname: 'P',
          identity: 'attacker',
        ),
        JoinRoomStatus.rateLimited,
      );

      m.clock.advanceMs(60000);
      expect(
        m.manager.joinRoom(
          code: code,
          connectionId: 'cy',
          playerId: 'py',
          nickname: 'P',
          identity: 'attacker',
        ),
        isNot(JoinRoomStatus.rateLimited),
      );
    });

    test('other identities are unaffected', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      for (var i = 0; i < 10; i++) {
        m.manager.joinRoom(
          code: code,
          connectionId: 'a$i',
          playerId: 'ap$i',
          nickname: 'A',
          identity: 'ip-a',
        );
      }
      expect(
        m.manager.joinRoom(
          code: code,
          connectionId: 'b1',
          playerId: 'bp1',
          nickname: 'B',
          identity: 'ip-b',
        ),
        isNot(JoinRoomStatus.rateLimited),
      );
    });

    test('rateLimited join leaves no seat and no connection mapping', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      for (var i = 2; i <= 11; i++) {
        m.manager.joinRoom(
          code: code,
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'attacker',
        );
      }
      final room = m.manager.roomByCode(code)!;
      final seats = room.players.length;
      expect(
        m.manager.joinRoom(
          code: code,
          connectionId: 'c99',
          playerId: 'p99',
          nickname: 'P99',
          identity: 'attacker',
        ),
        JoinRoomStatus.rateLimited,
      );
      expect(room.players.length, seats);
    });
  });

  group('net_5_4 create rate limit', () {
    test('5 creates per minute allowed, 6th rateLimited', () {
      final m = makeManager();
      for (var i = 0; i < 5; i++) {
        final r = m.manager.createRoom(
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'creator',
        );
        expect(r.status, CreateRoomStatus.ok);
      }
      final sixth = m.manager.createRoom(
        connectionId: 'c5',
        playerId: 'p5',
        nickname: 'P5',
        identity: 'creator',
      );
      expect(sixth.status, CreateRoomStatus.rateLimited);
      expect(m.manager.roomCount, 5);
    });

    test('create window resets after 60 seconds', () {
      final m = makeManager(startMs: 0);
      for (var i = 0; i < 5; i++) {
        m.manager.createRoom(
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'creator',
        );
      }
      m.clock.advanceMs(60000);
      final r = m.manager.createRoom(
        connectionId: 'c9',
        playerId: 'p9',
        nickname: 'P9',
        identity: 'creator',
      );
      expect(r.status, CreateRoomStatus.ok);
    });
  });

  group('rate counter cleanup', () {
    test('sweep prunes identities idle for a full window', () {
      final m = makeManager(startMs: 0);
      m.manager.createRoom(
        connectionId: 'c0',
        playerId: 'p0',
        nickname: 'P0',
        identity: 'transient',
      );
      expect(m.manager.trackedRateIdentities, contains('transient'));

      m.manager.sweep(60000);

      expect(m.manager.trackedRateIdentities, isEmpty);
    });

    test('sweep keeps identities with a recent attempt', () {
      final m = makeManager(startMs: 0);
      m.manager.createRoom(
        connectionId: 'c0',
        playerId: 'p0',
        nickname: 'P0',
        identity: 'active',
      );
      m.clock.advanceMs(30000);

      m.manager.sweep(30000);

      expect(m.manager.trackedRateIdentities, contains('active'));
    });
  });
}
