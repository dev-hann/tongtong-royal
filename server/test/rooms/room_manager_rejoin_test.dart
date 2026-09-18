import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('net_5_1 host disconnect', () {
    test('marks host seat reserved, room stays alive in grace', () {
      final m = makeManager();
      final code = hostRoom(m.manager);

      m.manager.disconnect('host-conn');

      final room = m.manager.roomByCode(code)!;
      final seat = room.players['host-conn']!;
      expect(seat.connected, isFalse);
      expect(seat.isReserved, isTrue);
      expect(seat.disconnectedAtMs, 1000);
      expect(m.manager.sweep(10500), isEmpty);
    });

    test('host rejoin within grace resumes seat and host role', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.disconnect('host-conn');
      m.clock.advanceMs(4000);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'host-conn-2',
        playerId: 'host',
        nickname: 'Host',
        identity: 'ip-host',
      );

      expect(status, RejoinRoomStatus.ok);
      final room = m.manager.roomByCode(code)!;
      expect(room.hostConnectionId, 'host-conn-2');
      expect(room.players, isNot(contains('host-conn')));
      final seat = room.players['host-conn-2']!;
      expect(seat.playerId, 'host');
      expect(seat.connected, isTrue);
      expect(seat.disconnectedAtMs, isNull);
    });

    test('grace not expired one millisecond early', () {
      final m = makeManager();
      hostRoom(m.manager);
      m.manager.disconnect('host-conn');

      expect(m.manager.sweep(10999), isEmpty);
      expect(m.manager.roomCount, 1);
    });

    test('grace expiry closes room with hostLeft event', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.disconnect('host-conn');

      final events = m.manager.sweep(11000);

      expect(
        events,
        contains(isA<HostGraceExpired>().having((e) => e.roomCode,
            'roomCode', code)),
      );
      expect(m.manager.roomCount, 0);
      expect(m.manager.roomByCode(code), isNull);
    });

    test('expired host grace also drops remaining seats', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.disconnect('host-conn');
      m.manager.sweep(11000);

      // Room is gone entirely; the other player has no seat left.
      expect(m.manager.leaveRoom('p2-conn'), LeaveRoomStatus.notInRoom);
    });
  });

  group('net_5_2 player disconnect', () {
    test('marks seat reserved; match continues without events', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);

      m.manager.disconnect('p2-conn');

      final room = m.manager.roomByCode(code)!;
      expect(room.players['p2-conn']!.isReserved, isTrue);
      expect(room.phase, RoomPhase.inMatch);
      expect(m.manager.sweep(1500), isEmpty);
    });

    test('rejoin within grace resumes seat as player', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.disconnect('p2-conn');
      m.clock.advanceMs(5000);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'p2-conn-2',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(status, RejoinRoomStatus.ok);
      final room = m.manager.roomByCode(code)!;
      final seat = room.players['p2-conn-2']!;
      expect(seat.playerId, 'p2');
      expect(seat.connected, isTrue);
      expect(seat.isSpectator, isFalse);
      expect(room.phase, RoomPhase.inMatch);
    });

    test('grace expiry removes seat, forfeits, match continues', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.disconnect('p2-conn');

      final events = m.manager.sweep(11000);

      expect(
        events,
        contains(
          isA<PlayerGraceExpired>()
              .having((e) => e.roomCode, 'roomCode', code)
              .having((e) => e.playerId, 'playerId', 'p2')
              .having((e) => e.forfeited, 'forfeited', true),
        ),
      );
      final room = m.manager.roomByCode(code)!;
      expect(room.players, isNot(contains('p2-conn')));
      expect(room.phase, RoomPhase.inMatch);
      expect(room.players, contains('host-conn'));
    });

    test('rejoin after grace during match: forfeit, joins as spectator',
        () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.disconnect('p2-conn');
      m.manager.sweep(11000);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'p2-conn-2',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(status, RejoinRoomStatus.matchForfeit);
      final seat = m.manager.roomByCode(code)!.players['p2-conn-2']!;
      expect(seat.isSpectator, isTrue);
      expect(seat.connected, isTrue);
    });

    test('rejoin after grace in lobby re-enters as regular player', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.disconnect('p2-conn');
      m.manager.sweep(11000);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'p2-conn-2',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(status, RejoinRoomStatus.ok);
      final room = m.manager.roomByCode(code)!;
      expect(room.phase, RoomPhase.lobby);
      expect(room.players['p2-conn-2']!.isSpectator, isFalse);
    });

    test('stale reserved seat past grace forfeits even without sweep', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.disconnect('p2-conn');
      // No sweep call; rejoin arrives 20 s later.
      m.clock.advanceMs(20000);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'p2-conn-2',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(status, RejoinRoomStatus.matchForfeit);
      final room = m.manager.roomByCode(code)!;
      expect(room.players['p2-conn-2']!.isSpectator, isTrue);
      expect(room.players, isNot(contains('p2-conn')));
    });

    test('spectator grace expiry is not a forfeit', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'spec-conn',
        playerId: 'spec',
        nickname: 'Spec',
        identity: 'ip-spec',
      );
      m.manager.disconnect('spec-conn');

      final events = m.manager.sweep(11000);

      expect(
        events,
        contains(
          isA<PlayerGraceExpired>()
              .having((e) => e.playerId, 'playerId', 'spec')
              .having((e) => e.forfeited, 'forfeited', false),
        ),
      );
    });
  });

  group('rejoin guards', () {
    test('unknown code yields notFound', () {
      final m = makeManager();
      final status = m.manager.rejoinRoom(
        code: 'ZZZZZZ',
        connectionId: 'c1',
        playerId: 'p1',
        nickname: 'P1',
        identity: 'ip-1',
      );
      expect(status, RejoinRoomStatus.notFound);
    });

    test('net_6 rejoin while connected on second socket rejected', () {
      final m = makeManager();
      final code = hostRoom(m.manager);

      final status = m.manager.rejoinRoom(
        code: code,
        connectionId: 'clone-conn',
        playerId: 'host',
        nickname: 'Clone',
        identity: 'ip-2',
      );

      expect(status, RejoinRoomStatus.alreadyConnected);
      final room = m.manager.roomByCode(code)!;
      expect(room.players, isNot(contains('clone-conn')));
    });
  });
}
