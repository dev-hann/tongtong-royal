import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One sample instance of every WireMessage subtype.
List<WireMessage> _allMessages() {
  return [
    const Hello(
      protocolVersion: protocolVersion,
      playerId: '00000000-0000-4000-8000-000000000000',
      nickname: '통통이',
    ),
    const CreateRoom(),
    const JoinRoom(code: 'ABC234'),
    const RejoinRoom(code: 'XYZ789'),
    const LeaveRoom(),
    const SetReady(ready: true),
    const SetReady(ready: false),
    const StartMatch(),
    PlayerInputMessage(
      seq: 123456,
      moveX: -0.75,
      moveY: 1,
      jump: true,
      dash: true,
    ),
    const VersionMismatch(status: VersionStatus.ok),
    const VersionMismatch(status: VersionStatus.clientTooOld),
    const VersionMismatch(status: VersionStatus.serverTooOld),
    const EndMatch(),
    const RateLimited(),
    const AlreadyConnected(),
    const ServerFull(),
    const JoinFailed(reason: JoinFailReason.notFound),
    const JoinFailed(reason: JoinFailReason.roomFull),
    RoomSnapshot(
      code: 'ABC234',
      players: List<PlayerInfo>.unmodifiable(const [
        PlayerInfo(playerId: 'p1', nickname: 'host', ready: true),
        PlayerInfo(playerId: 'p2', nickname: 'guest', ready: false),
        PlayerInfo(
          playerId: 'p3',
          nickname: 'reserved',
          ready: false,
          connected: false,
        ),
        PlayerInfo(
          playerId: 'p4',
          nickname: 'watcher',
          ready: false,
          isSpectator: true,
        ),
      ]),
      phase: RoundPhase.roundPlay,
      roundIndex: 3,
    ),
    const RoundStarting(
      roundIndex: 4,
      minigameId: 'trap_race',
      mapSeed: 987654321,
      timeoutMs: 60000,
    ),
    Snapshot(
      tick: 918273,
      players: List<PlayerState>.unmodifiable([
        const PlayerState(
          playerId: 'p1',
          x: 1.23,
          y: -2.72,
          angle: 3.14,
          vx: -0.11,
          vy: 1,
        ),
        const PlayerState(playerId: 'p2', x: 0, y: 0, angle: 0, vx: 0, vy: 0),
      ]),
    ),
    const RoundResultsMessage(
      roundResult: RoundResult(
        roundIndex: 2,
        minigameId: 'trap_race',
        placements: [
          Placement(playerId: 'p1', rank: 1, points: 5),
          Placement(playerId: 'p2', rank: 2, points: 3),
        ],
      ),
    ),
    const RoomClosed(reason: RoomCloseReason.hostLeft),
    const RoomClosed(reason: RoomCloseReason.serverShutdown),
    const RoomClosed(reason: RoomCloseReason.empty),
    const Ping(),
    const Pong(),
  ];
}

void main() {
  group('roundtrip', () {
    for (final msg in _allMessages()) {
      test('${msg.runtimeType} preserves all fields', () {
        final decoded = decode(encode(msg));
        expect(decoded.runtimeType, msg.runtimeType);
        expect(decoded, equals(msg));
      });
    }

    test('decoded equality is structural for snapshots', () {
      final msg = _allMessages().whereType<Snapshot>().first;
      final again = decode(encode(decode(encode(msg))));
      expect(again, equals(msg));
    });
  });

  group('quantization', () {
    test('1.23456789 becomes 1.23 on the wire', () {
      const state = PlayerState(
        playerId: 'p1',
        x: 1.23456789,
        y: 1.23456789,
        angle: 1.23456789,
        vx: 1.23456789,
        vy: 1.23456789,
      );
      final json = encode(const Snapshot(tick: 1, players: [state]));
      expect(json.contains('1.23'), isTrue);
      expect(json.contains('1.23456789'), isFalse);
    });

    test('1.23456789 decodes back as 1.23 both ways', () {
      const state = PlayerState(
        playerId: 'p1',
        x: 1.23456789,
        y: 1.23456789,
        angle: 1.23456789,
        vx: 1.23456789,
        vy: 1.23456789,
      );
      final decoded =
          decode(encode(const Snapshot(tick: 1, players: [state]))) as Snapshot;
      final p = decoded.players.single;
      expect(p.x, 1.23);
      expect(p.y, 1.23);
      expect(p.angle, 1.23);
      expect(p.vx, 1.23);
      expect(p.vy, 1.23);
    });

    test('non-finite numbers collapse to 0.0 at the boundary', () {
      const state = PlayerState(
        playerId: 'p1',
        x: double.nan,
        y: double.infinity,
        angle: double.negativeInfinity,
        vx: 0,
        vy: 0,
      );
      final decoded =
          decode(encode(const Snapshot(tick: 1, players: [state]))) as Snapshot;
      final p = decoded.players.single;
      expect(p.x, 0.0);
      expect(p.y, 0.0);
      expect(p.angle, 0.0);
    });
  });

  group('size budget', () {
    Snapshot worstCaseSnapshot() {
      final players = List<PlayerState>.unmodifiable(
        List.generate(
          4,
          (i) => PlayerState(
            playerId: '00000000-0000-4000-8000-00000000000$i',
            x: -500,
            y: -500,
            angle: -999.99,
            vx: -20,
            vy: -20,
          ),
        ),
      );
      return Snapshot(tick: 2147483647, players: players);
    }

    test('maximal 4-player snapshot stays under 2048 bytes', () {
      final encoded = encode(worstCaseSnapshot());
      // Network doc § 7: snapshot budget is 2 KB for 4 players.
      expect(encoded.length, lessThan(2048), reason: encoded);
    });

    test('oversized string trips assertSize', () {
      final huge = 'a' * 5000;
      expect(() => assertSize(huge), throwsA(isA<ProtocolException>()));
    });

    test('message exactly at cap passes assertSize', () {
      expect(() => assertSize('a' * maxMessageBytes), returnsNormally);
    });

    test('maximal RoomSnapshot with seat flags stays under the cap', () {
      final snapshot = RoomSnapshot(
        code: 'ABC234',
        players: List<PlayerInfo>.unmodifiable(
          List.generate(
            4,
            (i) => PlayerInfo(
              playerId: '00000000-0000-4000-8000-00000000000$i',
              nickname: 'nickname-$i',
              ready: true,
              connected: i.isEven,
              isSpectator: i.isOdd,
            ),
          ),
        ),
        phase: RoundPhase.roundPlay,
        roundIndex: 2147483647,
      );
      final encoded = encode(snapshot);
      expect(encoded.length, lessThan(maxMessageBytes), reason: encoded);
    });
  });

  group('decode rejection', () {
    test('unknown tag throws ProtocolException', () {
      expect(
        () => decode('{"t":"definitely_not_a_tag","v":{}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('malformed JSON throws ProtocolException', () {
      expect(() => decode('{"t":'), throwsA(isA<ProtocolException>()));
    });

    test('non-object envelope throws ProtocolException', () {
      expect(() => decode('[1,2,3]'), throwsA(isA<ProtocolException>()));
    });

    test('missing tag field throws ProtocolException', () {
      expect(() => decode('{"v":{}}'), throwsA(isA<ProtocolException>()));
    });

    test('missing payload field throws ProtocolException', () {
      expect(() => decode('{"t":"ping"}'), throwsA(isA<ProtocolException>()));
    });

    test(
      'missing payload field throws ProtocolException for typed messages',
      () {
        expect(
          () => decode('{"t":"join_room","v":{}}'),
          throwsA(isA<ProtocolException>()),
        );
      },
    );

    test('wrong field type throws ProtocolException', () {
      expect(
        () => decode('{"t":"join_room","v":{"code":123}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('wrong bool type throws ProtocolException', () {
      expect(
        () => decode('{"t":"set_ready","v":{"ready":"yes"}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('wrong int type throws ProtocolException', () {
      expect(
        () => decode(
          '{"t":"hello","v":{"protocolVersion":"1",'
          '"playerId":"p","nickname":"n"}}',
        ),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('unknown enum value throws ProtocolException', () {
      expect(
        () => decode('{"t":"room_closed","v":{"reason":"alienInvasion"}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('unknown version status throws ProtocolException', () {
      expect(
        () => decode('{"t":"version_mismatch","v":{"status":"nope"}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('malformed nested player entry throws ProtocolException', () {
      expect(
        () => decode('{"t":"snapshot","v":{"tick":1,"players":["p1"]}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('ProtocolException carries a reason', () {
      Object? caught;
      try {
        decode('{"t":"join_room","v":{}}');
      } on ProtocolException catch (e) {
        caught = e;
        expect(e.reason, isNotEmpty);
      }
      expect(caught, isA<ProtocolException>());
    });
  });

  group('PlayerInputMessage attribution', () {
    PlayerInputMessage attributed(String playerId) => PlayerInputMessage(
      seq: 9,
      moveX: 0.5,
      moveY: -0.5,
      jump: true,
      dash: false,
      playerId: playerId,
    );

    test('roundtrips with the playerId preserved', () {
      final msg = attributed('member-1');
      final decoded = decode(encode(msg));
      expect(decoded, equals(msg));
      expect((decoded as PlayerInputMessage).playerId, 'member-1');
    });

    test('roundtrips without playerId as null', () {
      final msg = PlayerInputMessage(
        seq: 9,
        moveX: 0.5,
        moveY: -0.5,
        jump: true,
        dash: false,
      );
      final decoded = decode(encode(msg)) as PlayerInputMessage;
      expect(decoded.playerId, isNull);
      expect(decoded, equals(msg));
    });

    test('encode omits the playerId key when unset', () {
      final msg = PlayerInputMessage(
        seq: 9,
        moveX: 0,
        moveY: 0,
        jump: false,
        dash: false,
      );
      expect(encode(msg).contains('playerId'), isFalse);
    });

    test('encode includes the playerId key when set', () {
      expect(encode(attributed('member-1')).contains('playerId'), isTrue);
    });

    test('old payload without playerId decodes with playerId null', () {
      final decoded = decode(
        '{"t":"input","v":{"seq":9,"moveX":0.5,"moveY":-0.5,'
        '"jump":true,"dash":false}}',
      ) as PlayerInputMessage;
      expect(decoded.seq, 9);
      expect(decoded.moveX, 0.5);
      expect(decoded.jump, isTrue);
      expect(decoded.playerId, isNull);
    });

    test('wrong playerId type throws ProtocolException', () {
      expect(
        () => decode(
          '{"t":"input","v":{"seq":9,"moveX":0,"moveY":0,'
          '"jump":false,"dash":false,"playerId":42}}',
        ),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('messages differing only in playerId are not equal', () {
      expect(attributed('a'), isNot(equals(attributed('b'))));
      expect(attributed('a').hashCode, isNot(attributed('b').hashCode));
    });
  });

  group('PlayerInfo seat-flag back-compat', () {
    test('payload without the new keys decodes with defaults', () {
      final decoded = decode(
        '{"t":"room_snapshot","v":{"code":"ABC234","players":['
        '{"playerId":"p1","nickname":"host","ready":true}],'
        '"phase":"lobby","roundIndex":0}}',
      ) as RoomSnapshot;
      final player = decoded.players.single;
      expect(
        player.connected,
        isTrue,
        reason: 'absent connected must default to true',
      );
      expect(
        player.isSpectator,
        isFalse,
        reason: 'absent isSpectator must default to false',
      );
    });

    test('payload with the new keys roundtrips them', () {
      final decoded = decode(
        '{"t":"room_snapshot","v":{"code":"ABC234","players":['
        '{"playerId":"p1","nickname":"host","ready":true,'
        '"connected":false,"isSpectator":true}],'
        '"phase":"lobby","roundIndex":0}}',
      ) as RoomSnapshot;
      final player = decoded.players.single;
      expect(player.connected, isFalse);
      expect(player.isSpectator, isTrue);
    });

    test('wrong type for the new keys throws ProtocolException', () {
      expect(
        () => decode(
          '{"t":"room_snapshot","v":{"code":"ABC234","players":['
          '{"playerId":"p1","nickname":"host","ready":true,'
          '"connected":"yes"}],"phase":"lobby","roundIndex":0}}',
        ),
        throwsA(isA<ProtocolException>()),
      );
    });
  });

  group('JoinFailed', () {
    test('unknown reason throws ProtocolException', () {
      expect(
        () => decode('{"t":"join_failed","v":{"reason":"alienInvasion"}}'),
        throwsA(isA<ProtocolException>()),
      );
    });

    test('missing reason throws ProtocolException', () {
      expect(
        () => decode('{"t":"join_failed","v":{}}'),
        throwsA(isA<ProtocolException>()),
      );
    });
  });

  group('tag table', () {
    test('every WireMessage subtype has a registered tag', () {
      for (final msg in _allMessages()) {
        expect(
          messageTags[msg.runtimeType],
          isNotNull,
          reason: '${msg.runtimeType} has no tag',
        );
      }
    });

    test('all tags are unique', () {
      final values = messageTags.values.toList();
      expect(values.toSet().length, values.length);
    });

    test('every tag has a decoder', () {
      for (final tag in messageTags.values) {
        expect(
          messageDecoders.containsKey(tag),
          isTrue,
          reason: 'tag "$tag" has no decoder',
        );
      }
    });

    test('decoder tags and tag table agree', () {
      expect({...messageTags.values}.containsAll(messageDecoders.keys), isTrue);
      expect({...messageDecoders.keys}.containsAll(messageTags.values), isTrue);
    });
  });
}
