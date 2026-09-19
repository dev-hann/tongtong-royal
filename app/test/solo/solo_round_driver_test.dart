import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:app/solo/solo_round_driver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

import 'fake_solo_sim.dart';

/// Brain stub: records observations, replays a fixed input.
final class _RecordingBrain implements BotBrain {
  final List<BotObservation> observations = [];
  PlayerInputState reply = PlayerInputState();

  @override
  PlayerInputState decide(BotObservation obs) {
    observations.add(obs);
    return reply;
  }
}

/// Input source stub: replays a fixed state.
final class _StaticInput implements InputSource {
  _StaticInput(this.state);

  PlayerInputState state;

  @override
  PlayerInputState sample() => state;
}

void main() {
  const roster = {'solo-player', 'bot-1', 'bot-2', 'bot-3'};
  const humanId = 'solo-player';

  SoloRoundDriver buildDriver(
    FakeSoloSim sim, {
    Map<PlayerId, BotBrain> brains = const {},
    InputSource? humanInput,
    Object map = const _NoMap(),
    void Function(RoundResult result)? onComplete,
    MiniGame game = const TrapRace(),
  }) {
    return SoloRoundDriver(
      simulation: sim,
      game: game,
      roundIndex: 0,
      roster: roster,
      humanId: humanId,
      brains: brains,
      map: map,
      humanInput: humanInput,
      onRoundComplete: onComplete ?? (_) {},
    );
  }

  test('feeds the human input and one bot decision per tick', () {
    final sim = FakeSoloSim(minigameId: 'trap_race', roster: roster);
    final bot = _RecordingBrain()
      ..reply = PlayerInputState(moveDir: Vector2(1, 0));
    buildDriver(
      sim,
      brains: {'bot-1': bot},
      humanInput: _StaticInput(PlayerInputState(jumpPressed: true)),
    ).tick();

    final inputs = sim.inputLog.single;
    expect(inputs.containsKey(humanId), isTrue);
    expect(inputs[humanId]!.jumpPressed, isTrue);
    expect(inputs.containsKey('bot-1'), isTrue);
    expect(inputs['bot-1']!.moveDir.x, 1);
    expect(inputs.containsKey('bot-2'), isFalse);
  });

  test('an eliminated bot receives no input entry (idle body)', () {
    final sim = FakeSoloSim(minigameId: 'hammer_dodge', roster: roster)
      ..eliminated.add('bot-1');
    final bot = _RecordingBrain();
    buildDriver(sim, brains: {'bot-1': bot}).tick();

    expect(sim.inputLog.single.containsKey('bot-1'), isFalse);
    expect(bot.observations, isEmpty);
  });

  test('grounded is approximated from vertical speed', () {
    final sim = FakeSoloSim(minigameId: 'hammer_dodge', roster: roster)
      ..poses['bot-1'] = (x: 0, y: 1, angle: 0, vx: 0, vy: 0.1)
      ..poses['bot-2'] = (x: 2, y: 3, angle: 0, vx: 0, vy: -4);
    final grounded = _RecordingBrain();
    final airborne = _RecordingBrain();
    buildDriver(sim, brains: {'bot-1': grounded, 'bot-2': airborne}).tick();

    expect(grounded.observations.single.grounded, isTrue);
    expect(airborne.observations.single.grounded, isFalse);
  });

  test('nearby players are exposed within the awareness radius', () {
    final sim = FakeSoloSim(minigameId: 'hammer_dodge', roster: roster)
      ..poses['bot-1'] = (x: 0, y: 0, angle: 0, vx: 0, vy: 0)
      ..poses['bot-2'] = (x: 3, y: 0, angle: 0, vx: 0, vy: 0)
      ..poses['bot-3'] = (x: 50, y: 0, angle: 0, vx: 0, vy: 0);
    final bot = _RecordingBrain();
    buildDriver(sim, brains: {'bot-1': bot}).tick();

    final others = bot.observations.single.nearbyPlayers;
    expect(others, hasLength(2));
  });

  test('course hammer hazards advance per tick', () {
    final map = CourseMap.trapRace(5);
    final sim = FakeSoloSim(minigameId: 'trap_race', roster: roster)
      ..poses['bot-1'] = (x: 5, y: 2, angle: 0, vx: 0, vy: 0);
    final bot = _RecordingBrain();
    buildDriver(sim, brains: {'bot-1': bot}, map: map)
      ..tick()
      ..tick();

    final first = bot.observations[0].nearbyHazards;
    final second = bot.observations[1].nearbyHazards;
    expect(first, isNotEmpty);
    expect(first.length, second.length);
    for (var i = 0; i < first.length; i++) {
      final drifted = second[i].angle - first[i].angle;
      final expected = first[i].angularVelocity * PhysicsConsts.fixedDt;
      expect(drifted, closeTo(expected, 1e-9));
    }
  });

  test('sim completion resolves through the domain exactly once', () {
    final sim = FakeSoloSim(
      minigameId: 'trap_race',
      roster: roster,
      completeAfterTicks: 3,
      progressAnchor: 0,
    );
    var completions = 0;
    RoundResult? result;
    final driver = buildDriver(
      sim,
      onComplete: (r) {
        completions++;
        result = r;
      },
    );

    // Two finishers (staggered ticks), the rest ranked by progress.
    sim.poses['solo-player'] = (x: 40, y: 0, angle: 0, vx: 0, vy: 0);
    sim.poses['bot-1'] = (x: 30, y: 0, angle: 0, vx: 0, vy: 0);
    driver.tick();
    sim.emit(const PlayerFinished(tick: 1, playerId: 'bot-2'));
    driver.tick();
    sim.emit(const PlayerFinished(tick: 2, playerId: 'bot-3'));
    driver.tick();

    expect(completions, 1);
    expect(driver.isRoundOver, isTrue);
    final placements = result!.placements;
    expect(placements, hasLength(4));
    expect(placements.first.playerId, 'bot-2');
    expect(placements[1].playerId, 'bot-3');
    // Unfinished: further progress first (GDD § 7.4).
    expect(placements[2].playerId, 'solo-player');

    // Post-completion ticks and input builds are inert.
    driver.tick();
    expect(driver.buildInputs(), isEmpty);
    expect(completions, 1);
    expect(sim.tickCount, 3);
  });

  test('a never-completing sim ends at the spec timeout', () {
    final sim =
        FakeSoloSim(
            minigameId: 'trap_race',
            roster: roster,
            completeAfterTicks: null,
            progressAnchor: 0,
          )
          ..poses['solo-player'] = (x: 9, y: 0, angle: 0, vx: 0, vy: 0)
          ..poses['bot-1'] = (x: 5, y: 0, angle: 0, vx: 0, vy: 0)
          ..poses['bot-2'] = (x: 7, y: 0, angle: 0, vx: 0, vy: 0)
          ..poses['bot-3'] = (x: 1, y: 0, angle: 0, vx: 0, vy: 0);
    late RoundResult result;
    final driver = buildDriver(sim, onComplete: (r) => result = r);

    while (!driver.isRoundOver) {
      driver.tick();
    }

    // 90 s * 60 Hz spec timeout (TrapRace), in ticks.
    expect(sim.tickCount, 90 * PhysicsConsts.tickRate);
    expect(result.placements, hasLength(4));
    expect(result.placements.first.playerId, 'solo-player');
    expect(result.placements.last.playerId, 'bot-3');
  });

  test('progress sampling is skipped for sims without an anchor', () {
    final sim = FakeSoloSim(minigameId: 'trap_race', roster: roster);
    var completions = 0;
    final driver = buildDriver(sim, onComplete: (_) => completions++);
    sim.emit(const PlayerFinished(tick: 1, playerId: 'bot-1'));

    driver
      ..tick()
      ..tick();

    expect(completions, 1);
  });

  test('finishTickOf_returns_the_finisher_event_tick', () {
    final sim = FakeSoloSim(minigameId: 'trap_race', roster: roster);
    final driver = buildDriver(sim);
    sim.emit(const PlayerFinished(tick: 7, playerId: humanId));

    driver.tick();

    expect(driver.finishTickOf(humanId), 7);
  });

  test('finishTickOf_returns_null_for_a_non_finisher', () {
    final sim = FakeSoloSim(minigameId: 'trap_race', roster: roster);
    final driver = buildDriver(sim);
    sim.emit(const PlayerFinished(tick: 7, playerId: 'bot-1'));

    driver.tick();

    expect(driver.finishTickOf(humanId), isNull);
  });
}

/// Marker map type the driver treats as hazard-free.
final class _NoMap {
  const _NoMap();
}
