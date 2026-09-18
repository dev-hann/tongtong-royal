import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/player_character.dart';
import 'package:app/infra/net_client.dart';
import 'package:app/infra/net_log.dart';
import 'package:app/net/host/host_runtime.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import '../../infra/fake_connection.dart';

const PlayerId p1 = 'p1';
const PlayerId p2 = 'p2';

/// Flat single-platform course for scripted tests: a long floor, the
/// finish sensor [finishX] meters right of the spawn, nothing else.
/// Map data, not physics tuning (architecture doc § 3).
CourseMap flatCourse(int mapSeed, {double finishX = 2}) => CourseMap(
  mapSeed: mapSeed,
  spawnPoint: Vector2(0, PlayerCharacter.heightMeters / 2 + _spawnClearance),
  checkpoints: const [],
  finishLine: BoxSpec(center: Vector2(finishX, 1), width: 0.6, height: 3),
  killY: -6,
  platforms: [BoxSpec(center: Vector2(10, -0.5), width: 60, height: 1)],
  walls: const [],
  hammers: const [],
);

const double _spawnClearance = 0.01;

/// Deterministic Hammer Dodge arena: the factory variant without
/// hammer arms, so eliminations are input-driven only (fixture
/// parity with the HammerSimulation suite).
HammerArenaMap hammerlessArena(int mapSeed) {
  final base = HammerArenaMap.hammerArena(mapSeed);
  return HammerArenaMap(
    mapSeed: base.mapSeed,
    platformRadius: base.platformRadius,
    platformSegmentCount: base.platformSegmentCount,
    platformThickness: base.platformThickness,
    killRadius: base.killRadius,
    spawnPoints: base.spawnPoints,
    hammers: const [],
  );
}

PlayerInputMessage inputSample({
  required int seq,
  double moveX = 0,
  double moveY = 0,
  bool jump = false,
  bool dash = false,
  PlayerId? playerId,
}) => PlayerInputMessage(
  seq: seq,
  moveX: moveX,
  moveY: moveY,
  jump: jump,
  dash: dash,
  playerId: playerId,
);

/// In-memory [NetLog] recording warnings for drop assertions.
final class RecordingNetLog implements NetLog {
  final List<String> warnings = <String>[];

  @override
  void info(String message) {}

  @override
  void warn(String message) => warnings.add(message);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Real [NetClient] over a [FakeConnection] plus a [HostRuntime] on
/// an injectable simulation factory (testing doc § 4: headless,
/// zero wall clock).
final class HostHarness {
  HostHarness({
    Set<PlayerId> roster = const {p1},
    CourseMap Function(int mapSeed)? mapBuilder,
    RoundSimulationFactory? simulationFactory,
    NetLog? log,
  }) : fake = FakeConnection() {
    client = NetClient(
      connectionFactory: (_) async => fake,
      clock: () => Duration.zero,
      backoff: (_) async {},
    );
    runtime = HostRuntime(
      client: client,
      roster: roster,
      log: log,
      simulationFactory:
          simulationFactory ??
          (minigameId, mapSeed, players) => RaceSimulation.forTesting(
            map: mapBuilder?.call(mapSeed) ?? flatCourse(mapSeed),
            playerIds: players,
            stuckThresholdSeconds: 5,
          ),
    );
  }

  final FakeConnection fake;
  late final NetClient client;
  late final HostRuntime runtime;

  /// Connects and joins room `ABC234` (state `NetJoined`).
  Future<void> boot() async {
    await client.connect(Uri.parse('ws://test'), 'host', 'Host');
    client.createRoom();
    fake.serverSends(
      encode(
        const RoomSnapshot(
          code: 'ABC234',
          players: [
            PlayerInfo(playerId: 'host', nickname: 'Host', ready: true),
          ],
          phase: RoundPhase.lobby,
          roundIndex: 0,
        ),
      ),
    );
    await pumpEventQueue();
  }

  /// Every typed message the client put on the wire, in order.
  List<WireMessage> get sentMessages => [
    for (final frame in fake.sent) decode(frame),
  ];

  List<Snapshot> get snapshotsSent =>
      sentMessages.whereType<Snapshot>().toList();

  /// Advances one fixed timestep.
  void tick() => runtime.advance(PhysicsConsts.fixedDt);

  /// Drives [ticks] fixed steps, submitting a right-run input for
  /// [playerId] every other tick (30 Hz into 60 Hz, network doc § 1).
  /// Starts at input seq [seq] and returns the next unused seq.
  int driveRight({
    required PlayerId playerId,
    required int ticks,
    int seq = 0,
  }) {
    var next = seq;
    for (var i = 0; i < ticks && runtime.isRoundActive; i++) {
      if (i.isEven) {
        next++;
        runtime.submitMemberInput(playerId, inputSample(seq: next, moveX: 1));
      }
      tick();
    }
    return next;
  }
}
