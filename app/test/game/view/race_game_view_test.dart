import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Input source stub: always reports the same state.
final class _StaticInput implements InputSource {
  _StaticInput(this.state);

  final PlayerInputState state;

  @override
  PlayerInputState sample() => state;
}

void main() {
  late CourseMap map;
  late RaceSimulation sim;

  setUp(() {
    map = CourseMap.trapRace(7);
    sim = RaceSimulation(map: map, playerIds: ['p1']);
  });

  tearDown(() => sim.dispose());

  RaceGameView buildGame({InputSource? inputSource}) => RaceGameView(
    simulation: sim,
    localPlayerId: 'p1',
    map: map,
    inputSource: inputSource,
  );

  group('fixed-dt accumulator', () {
    test('N frames of fixedDt take exactly N steps', () {
      final game = buildGame();
      for (var i = 0; i < 120; i++) {
        game.update(PhysicsConsts.fixedDt);
      }
      expect(game.stepCount, 120);
      expect(sim.currentTick, 120);
    });

    test('double-dt frames take two steps each', () {
      final game = buildGame();
      for (var i = 0; i < 10; i++) {
        game.update(PhysicsConsts.fixedDt * 2);
      }
      expect(game.stepCount, 20);
    });

    test('a huge frame dt is clamped to maxStepsPerFrame', () {
      // 1 s at 60 Hz would demand 60 steps.
      final game = buildGame()..update(1);
      expect(game.stepCount, maxStepsPerFrame);
      // The backlog was discarded: another huge frame still yields at
      // most the clamped count (no spiral of death).
      game.update(1);
      expect(game.stepCount, maxStepsPerFrame * 2);
      expect(game.accumulatorSeconds, lessThan(PhysicsConsts.fixedDt));
    });
  });

  group('camera clamp', () {
    test('focus beyond the left edge clamps inside the course', () {
      final game = buildGame();
      final bounds = game.courseBounds;
      final target = game.cameraTargetFor(
        Vector2(bounds.minX - 100, 0),
        Vector2(12, 8),
      );
      expect(target.x, closeTo(bounds.minX + 6, 0.01));
    });

    test('focus beyond the right edge clamps inside the course', () {
      final game = buildGame();
      final bounds = game.courseBounds;
      final target = game.cameraTargetFor(
        Vector2(bounds.maxX + 100, 0),
        Vector2(12, 8),
      );
      expect(target.x, closeTo(bounds.maxX - 6, 0.01));
    });

    test('focus in mid-course is left alone', () {
      final game = buildGame();
      final focus = Vector2(15, -1);
      final target = game.cameraTargetFor(focus, Vector2(12, 8));
      expect(target.x, closeTo(focus.x, 0.01));
      expect(target.y, closeTo(focus.y, 0.01));
    });

    test('vertical focus clamps to the bounds', () {
      final game = buildGame();
      final bounds = game.courseBounds;
      final target = game.cameraTargetFor(
        Vector2(15, bounds.maxY + 100),
        Vector2(12, 8),
      );
      expect(target.y, closeTo(bounds.maxY - 4, 0.01));
    });
  });

  test('injected input source drives the local player', () {
    final startX = sim.bodyOf('p1').position.x;
    final game = buildGame(
      inputSource: _StaticInput(PlayerInputState(moveDir: Vector2(1, 0))),
    );
    for (var i = 0; i < 60; i++) {
      game.update(PhysicsConsts.fixedDt);
    }
    expect(sim.bodyOf('p1').position.x, greaterThan(startX + 0.5));
  });

  test('events pass through and the finish flag latches', () {
    final game = buildGame();
    final events = <RoundEvent>[];
    game.events.listen(events.add);

    sim.bodyOf('p1').setTransform(map.finishLine.center.clone(), 0);
    for (var i = 0; i < 30 && !game.finished; i++) {
      game.update(PhysicsConsts.fixedDt);
    }

    expect(game.finished, isTrue);
    expect(events.whereType<PlayerFinished>(), isNotEmpty);
  });

  group('multi-input extension', () {
    test('tickInputsProvider feeds every player each step', () {
      final twoPlayerSim = RaceSimulation(map: map, playerIds: ['p1', 'p2']);
      addTearDown(twoPlayerSim.dispose);
      final p1Start = twoPlayerSim.bodyOf('p1').position.x;
      final p2Start = twoPlayerSim.bodyOf('p2').position.x;
      final game = RaceGameView(
        simulation: twoPlayerSim,
        localPlayerId: 'p1',
        map: map,
        playerIds: const ['p1', 'p2'],
        tickInputsProvider: () => {
          'p1': PlayerInputState(moveDir: Vector2(1, 0)),
          'p2': PlayerInputState(moveDir: Vector2(1, 0)),
        },
      );

      for (var i = 0; i < 60; i++) {
        game.update(PhysicsConsts.fixedDt);
      }

      expect(twoPlayerSim.bodyOf('p1').position.x, greaterThan(p1Start + 0.5));
      expect(twoPlayerSim.bodyOf('p2').position.x, greaterThan(p2Start + 0.5));
    });

    test('onStep fires once per completed step', () {
      var steps = 0;
      final game = buildGame(
        inputSource: _StaticInput(PlayerInputState(moveDir: Vector2(1, 0))),
      )..onStep = () => steps++;
      for (var i = 0; i < 10; i++) {
        game.update(PhysicsConsts.fixedDt);
      }
      expect(steps, 10);
      expect(game.stepCount, 10);
    });

    test('a tickEnabled veto stops stepping entirely', () {
      final twoPlayerSim = RaceSimulation(map: map, playerIds: ['p1']);
      addTearDown(twoPlayerSim.dispose);
      var providerCalls = 0;
      final game = RaceGameView(
        simulation: twoPlayerSim,
        localPlayerId: 'p1',
        map: map,
        tickInputsProvider: () {
          providerCalls++;
          return const {};
        },
        tickEnabled: () => false,
      )..update(PhysicsConsts.fixedDt * 10);

      expect(game.stepCount, 0);
      expect(providerCalls, 0);
      expect(twoPlayerSim.currentTick, 0);
    });
  });
}
