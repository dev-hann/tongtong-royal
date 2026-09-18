import 'dart:math';

import 'package:test/test.dart';
import 'package:tongtong_server/tongtong_server.dart';

import 'test_support.dart';

void main() {
  group('create room', () {
    test('happy path: creator becomes host, phase lobby', () {
      final m = makeManager();
      final result = m.manager.createRoom(
        connectionId: 'c1',
        playerId: 'p1',
        nickname: 'Ana',
        identity: 'ip-1',
      );

      expect(result.status, CreateRoomStatus.ok);
      expect(result.roomCode, hasLength(6));
      expect(m.manager.roomCount, 1);

      final room = m.manager.roomByCode(result.roomCode)!;
      expect(room.hostConnectionId, 'c1');
      expect(room.phase, RoomPhase.lobby);
      expect(room.players, contains('c1'));
      expect(room.players['c1']!.playerId, 'p1');
      expect(room.players['c1']!.connected, isTrue);
    });

    test('createdAtMs and lastOccupiedAtMs come from injected clock', () {
      final m = makeManager(startMs: 5000);
      final result = m.manager.createRoom(
        connectionId: 'c1',
        playerId: 'p1',
        nickname: 'Ana',
        identity: 'ip-1',
      );
      final room = m.manager.roomByCode(result.roomCode)!;
      expect(room.createdAtMs, 5000);
      expect(room.lastOccupiedAtMs, 5000);
    });

    test('exceeding maxRooms yields serverFull', () {
      final m = makeManager(maxRooms: 3);
      for (var i = 0; i < 3; i++) {
        final r = m.manager.createRoom(
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'ip-$i',
        );
        expect(r.status, CreateRoomStatus.ok);
      }
      final fourth = m.manager.createRoom(
        connectionId: 'c9',
        playerId: 'p9',
        nickname: 'P9',
        identity: 'ip-9',
      );
      expect(fourth.status, CreateRoomStatus.serverFull);
      expect(m.manager.roomCount, 3);
    });

    test('net_8 default max concurrent rooms is 200', () {
      expect(defaultMaxRooms, 200);
      final m = makeManager();
      for (var i = 0; i < 200; i++) {
        final r = m.manager.createRoom(
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'ip-$i',
        );
        expect(r.status, CreateRoomStatus.ok);
      }
      final over = m.manager.createRoom(
        connectionId: 'cx',
        playerId: 'px',
        nickname: 'PX',
        identity: 'ip-x',
      );
      expect(over.status, CreateRoomStatus.serverFull);
    });

    test('connection already seated cannot create another room', () {
      final m = makeManager();
      hostRoom(m.manager);
      final second = m.manager.createRoom(
        connectionId: 'host-conn',
        playerId: 'host',
        nickname: 'Host',
        identity: 'ip-host',
      );
      expect(second.status, CreateRoomStatus.alreadyConnected);
    });
  });

  group('join room', () {
    test('happy path: second player seated, ok', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      final status = m.manager.joinRoom(
        code: code,
        connectionId: 'c2',
        playerId: 'p2',
        nickname: 'Bo',
        identity: 'ip-2',
      );
      expect(status, JoinRoomStatus.ok);
      final room = m.manager.roomByCode(code)!;
      expect(room.players['c2']!.playerId, 'p2');
      expect(room.players['c2']!.connected, isTrue);
    });

    test('unknown code yields notFound', () {
      final m = makeManager();
      final status = m.manager.joinRoom(
        code: 'ZZZZZZ',
        connectionId: 'c2',
        playerId: 'p2',
        nickname: 'Bo',
        identity: 'ip-2',
      );
      expect(status, JoinRoomStatus.notFound);
    });

    test('join updates lastOccupiedAtMs', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.clock.advanceMs(2500);
      m.manager.joinRoom(
        code: code,
        connectionId: 'c2',
        playerId: 'p2',
        nickname: 'Bo',
        identity: 'ip-2',
      );
      expect(m.manager.roomByCode(code)!.lastOccupiedAtMs, 3500);
    });

    test('net_6 duplicate join: second socket same playerId rejected', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      final status = m.manager.joinRoom(
        code: code,
        connectionId: 'c2',
        playerId: 'host',
        nickname: 'Clone',
        identity: 'ip-2',
      );
      expect(status, JoinRoomStatus.alreadyConnected);
      final room = m.manager.roomByCode(code)!;
      expect(room.players, isNot(contains('c2')));
    });

    test('join with playerId holding a reserved seat is rejected', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      m.manager.joinRoom(
        code: code,
        connectionId: 'c2',
        playerId: 'p2',
        nickname: 'Bo',
        identity: 'ip-2',
      );
      m.manager.disconnect('c2');

      final status = m.manager.joinRoom(
        code: code,
        connectionId: 'c3',
        playerId: 'p2',
        nickname: 'Bo',
        identity: 'ip-3',
      );
      expect(status, JoinRoomStatus.alreadyConnected);
    });

    test('fifth seat rejected with roomFull', () {
      final m = makeManager();
      final code = hostRoom(m.manager);
      for (var i = 2; i <= 4; i++) {
        final status = m.manager.joinRoom(
          code: code,
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'ip-$i',
        );
        expect(status, JoinRoomStatus.ok);
      }
      final fifth = m.manager.joinRoom(
        code: code,
        connectionId: 'c5',
        playerId: 'p5',
        nickname: 'P5',
        identity: 'ip-5',
      );
      expect(fifth, JoinRoomStatus.roomFull);
    });
  });

  group('invite code generation', () {
    test('seeded collision regenerates until code is free', () {
      // Codes drawn: AAAAAA, AAAAAA (collision), BBBBBB.
      final zeros = List<int>.filled(12, 0);
      final random = SequencedRandom([...zeros, 1, 1, 1, 1, 1, 1]);
      final m = makeManager(random: random);

      final first = m.manager.createRoom(
        connectionId: 'c1',
        playerId: 'p1',
        nickname: 'P1',
        identity: 'ip-1',
      );
      final second = m.manager.createRoom(
        connectionId: 'c2',
        playerId: 'p2',
        nickname: 'P2',
        identity: 'ip-2',
      );

      expect(first.roomCode, 'AAAAAA');
      expect(second.status, CreateRoomStatus.ok);
      expect(second.roomCode, 'BBBBBB');
      expect(m.manager.roomCount, 2);
    });

    test('generated codes stay in charset across many rooms', () {
      final m = makeManager(random: Random(99));
      final pattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');
      for (var i = 0; i < 50; i++) {
        final r = m.manager.createRoom(
          connectionId: 'c$i',
          playerId: 'p$i',
          nickname: 'P$i',
          identity: 'ip-$i',
        );
        expect(r.roomCode, matches(pattern));
      }
    });
  });
}
