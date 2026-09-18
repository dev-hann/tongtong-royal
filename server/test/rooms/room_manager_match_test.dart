import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('gdd_7_1 startMatch guards', () {
    test('happy: host and all players ready with 2+ players', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.setReady(connectionId: 'host-conn', ready: true);
      m.manager.setReady(connectionId: 'p2-conn', ready: true);

      expect(m.manager.startMatch('host-conn'), StartMatchStatus.ok);
      final room = m.manager.roomByCode(code)!;
      expect(room.phase, RoomPhase.inMatch);
    });

    test('notHost rejected', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.setReady(connectionId: 'host-conn', ready: true);
      m.manager.setReady(connectionId: 'p2-conn', ready: true);

      expect(
        m.manager.startMatch('p2-conn'),
        StartMatchStatus.notHost,
      );
      expect(m.manager.roomByCode(code)!.phase, RoomPhase.lobby);
    });

    test('playersNotReady when one player is unready', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.setReady(connectionId: 'host-conn', ready: true);

      expect(
        m.manager.startMatch('host-conn'),
        StartMatchStatus.playersNotReady,
      );
    });

    test('playersNotReady when host itself is unready', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.setReady(connectionId: 'p2-conn', ready: true);

      expect(
        m.manager.startMatch('host-conn'),
        StartMatchStatus.playersNotReady,
      );
    });

    test('tooFewPlayers with a single ready player', () {
      final m = makeManager();
      hostRoom(m.manager);
      m.manager.setReady(connectionId: 'host-conn', ready: true);

      expect(
        m.manager.startMatch('host-conn'),
        StartMatchStatus.tooFewPlayers,
      );
    });

    test('unknown connection yields notInRoom', () {
      final m = makeManager();
      expect(m.manager.startMatch('ghost'), StartMatchStatus.notInRoom);
    });

    test('disconnected reserved players do not block readiness', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p2-conn',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );
      m.manager.joinRoom(
        code: code,
        connectionId: 'p3-conn',
        playerId: 'p3',
        nickname: 'P3',
        identity: 'ip-3',
      );
      m.manager.disconnect('p3-conn');
      m.manager.setReady(connectionId: 'host-conn', ready: true);
      m.manager.setReady(connectionId: 'p2-conn', ready: true);

      expect(m.manager.startMatch('host-conn'), StartMatchStatus.ok);
    });
  });

  group('net_8 round-in-progress join', () {
    test('mid-match join succeeds as spectator', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);

      final status = m.manager.joinRoom(
        code: code,
        connectionId: 'p3-conn',
        playerId: 'p3',
        nickname: 'P3',
        identity: 'ip-3',
      );

      expect(status, JoinRoomStatus.joinedAsSpectator);
      expect(m.manager.roomByCode(code)!.players['p3-conn']!.isSpectator,
          isTrue);
    });

    test('endMatch returns to lobby and converts spectators', () {
      final m = makeManager();
      final code = activeMatchRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'p3-conn',
        playerId: 'p3',
        nickname: 'P3',
        identity: 'ip-3',
      );

      expect(m.manager.endMatch('host-conn'), EndMatchStatus.ok);

      final room = m.manager.roomByCode(code)!;
      expect(room.phase, RoomPhase.lobby);
      expect(room.players['p3-conn']!.isSpectator, isFalse);
      for (final seat in room.players.values) {
        expect(seat.ready, isFalse, reason: seat.playerId);
      }
    });

    test('endMatch by non-host rejected', () {
      final m = makeManager();
      activeMatchRoom(m.manager);
      expect(m.manager.endMatch('p2-conn'), EndMatchStatus.notHost);
    });

    test('endMatch without a running match rejected', () {
      final m = makeManager();
      hostRoom(m.manager);
      expect(m.manager.endMatch('host-conn'), EndMatchStatus.notInMatch);
    });

    test('setReady flips the flag', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      expect(
        m.manager.setReady(connectionId: 'host-conn', ready: true),
        SetReadyStatus.ok,
      );
      expect(m.manager.roomByCode(code)!.players['host-conn']!.ready,
          isTrue);
      expect(
        m.manager.setReady(connectionId: 'host-conn', ready: false),
        SetReadyStatus.ok,
      );
      expect(m.manager.roomByCode(code)!.players['host-conn']!.ready,
          isFalse);
    });

    test('setReady for unknown connection yields notInRoom', () {
      final m = makeManager();
      expect(
        m.manager.setReady(connectionId: 'ghost', ready: true),
        SetReadyStatus.notInRoom,
      );
    });
  });
}
