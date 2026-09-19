import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/view/arena/arena_game_view.dart';
import 'package:app/game/view/race_game_view.dart' show maxStepsPerFrame;
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  late HammerArenaMap hammerMap;
  late HammerSimulation sim;

  setUp(() {
    hammerMap = HammerArenaMap.hammerArena(3);
    sim = HammerSimulation(map: hammerMap, playerIds: const ['p1', 'p2']);
  });

  tearDown(() => sim.dispose());

  ArenaGameView buildHammer({bool Function()? tickEnabled}) =>
      ArenaGameView.hammer(
        simulation: sim,
        map: hammerMap,
        localPlayerId: 'p1',
        playerIds: const ['p1', 'p2'],
        tickInputsProvider: () => const {},
        tickEnabled: tickEnabled,
      );

  group('fixed-dt accumulator', () {
    test('N frames of fixedDt take exactly N steps', () {
      final game = buildHammer();
      for (var i = 0; i < 120; i++) {
        game.update(PhysicsConsts.fixedDt);
      }
      expect(game.stepCount, 120);
      // The sim's own tick may stop earlier: once the hammer round
      // completes (last survivor) it freezes internally while the
      // view loop keeps stepping no-ops.
      expect(sim.currentTick, greaterThan(0));
    });

    test('double-dt frames take two steps each', () {
      final game = buildHammer();
      for (var i = 0; i < 10; i++) {
        game.update(PhysicsConsts.fixedDt * 2);
      }
      expect(game.stepCount, 20);
    });

    test('a huge frame dt is clamped to maxStepsPerFrame', () {
      final game = buildHammer();
      int stepCountAfter(double dt) => (game..update(dt)).stepCount;
      // 1 s at 60 Hz would demand 60 steps.
      expect(stepCountAfter(1), maxStepsPerFrame);
      // The backlog was discarded: another huge frame still yields at
      // most the clamped count (no spiral of death).
      expect(stepCountAfter(1), maxStepsPerFrame * 2);
      expect(game.accumulatorSeconds, lessThan(PhysicsConsts.fixedDt));
    });

    test('a tickEnabled veto stops stepping entirely', () {
      var providerCalls = 0;
      final game = ArenaGameView.hammer(
        simulation: sim,
        map: hammerMap,
        localPlayerId: 'p1',
        tickInputsProvider: () {
          providerCalls++;
          return const {};
        },
        tickEnabled: () => false,
      )..update(PhysicsConsts.fixedDt * 10);
      expect(game.stepCount, 0);
      expect(providerCalls, 0);
      expect(sim.currentTick, 0);
    });

    test('onStep fires once per completed step', () {
      var steps = 0;
      final game = buildHammer()..onStep = () => steps++;
      for (var i = 0; i < 10; i++) {
        game.update(PhysicsConsts.fixedDt);
      }
      expect(steps, 10);
      expect(game.stepCount, 10);
    });

    test('non-finite and non-positive dt are ignored', () {
      final game = buildHammer()
        ..update(0)
        ..update(double.nan)
        ..update(-1);
      expect(game.stepCount, 0);
    });
  });

  group('camera clamp', () {
    test('focus beyond the left edge clamps inside the arena', () {
      final game = buildHammer();
      final bounds = game.arenaBounds;
      final target = game.cameraTargetFor(
        Vector2(bounds.minX - 100, 0),
        Vector2(12, 12),
      );
      expect(target.x, closeTo(bounds.minX + 6, 0.01));
    });

    test('focus beyond the right edge clamps inside the arena', () {
      final game = buildHammer();
      final bounds = game.arenaBounds;
      final target = game.cameraTargetFor(
        Vector2(bounds.maxX + 100, 0),
        Vector2(12, 12),
      );
      expect(target.x, closeTo(bounds.maxX - 6, 0.01));
    });

    test('focus beyond the bottom clamps inside the arena', () {
      final game = buildHammer();
      final bounds = game.arenaBounds;
      final target = game.cameraTargetFor(
        Vector2(0, bounds.minY - 100),
        Vector2(12, 12),
      );
      expect(target.y, closeTo(bounds.minY + 6, 0.01));
    });

    test('focus mid-arena is left alone', () {
      final game = buildHammer();
      final focus = Vector2(1.5, -0.5);
      final target = game.cameraTargetFor(focus, Vector2(12, 12));
      expect(target.x, closeTo(focus.x, 0.01));
      expect(target.y, closeTo(focus.y, 0.01));
    });
  });

  group('hammer arm kinematics', () {
    test('angle starts at the spec initial angle', () {
      final game = buildHammer();
      for (var i = 0; i < hammerMap.hammers.length; i++) {
        expect(
          game.armAngleFor(i),
          closeTo(hammerMap.hammers[i].initialAngle, 1e-9),
        );
      }
    });

    test('after N steps the angle is initial + speed * N * fixedDt', () {
      final game = buildHammer();
      const steps = 30;
      for (var i = 0; i < steps; i++) {
        game.update(PhysicsConsts.fixedDt);
      }
      for (var i = 0; i < hammerMap.hammers.length; i++) {
        final spec = hammerMap.hammers[i];
        final expected =
            spec.initialAngle +
            spec.angularSpeed * steps * PhysicsConsts.fixedDt;
        expect(game.armAngleFor(i), closeTo(expected, 1e-6));
      }
    });
  });

  group('render poses', () {
    test('eliminated players (poseOf null) are excluded', () {
      final game = buildHammer();
      // Fling p2 far past the kill radius, then step once: the
      // post-step guard eliminates and destroys the body.
      sim
          .bodyOf('p2')
          .setTransform(Vector2(hammerMap.killRadius + 5, 0), 0);
      game.update(PhysicsConsts.fixedDt);

      expect(sim.poseOf('p2'), isNull);
      final ids = game.renderPoses.map((pose) => pose.id).toList();
      expect(ids, contains('p1'));
      expect(ids, isNot(contains('p2')));
    });

    test('surviving players keep their poses', () {
      final game = buildHammer()..update(PhysicsConsts.fixedDt);
      final poses = game.renderPoses;
      expect(poses.length, 2);
      expect(poses.first.id, 'p1');
    });
  });
}
