import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/arenas/hill/hill_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless hill fixtures: fixed-dt stepping only, no wall clock
/// (testing doc § 4). Generous tick budgets keep the tests robust
/// against solver jitter without timing assertions.
const int _maxTicks = 600;

PlayerInputState _idle() => PlayerInputState();

/// Runs [sim] with [inputs] until [isDone] holds after a tick.
/// Fails the test if it never holds within [_maxTicks].
void _runUntil(
  HillSimulation sim,
  Map<String, PlayerInputState> inputs,
  bool Function() isDone,
) {
  for (var i = 0; i < _maxTicks; i++) {
    sim.tickInputs(inputs);
    if (isDone()) {
      return;
    }
  }
  fail('condition never met within $_maxTicks ticks');
}

Vector2 _onCrownTop(HillArenaMap map, double offsetX) => Vector2(
      map.crownCenter.x + offsetX,
      map.crownTopY + 0.76 + 0.01,
    );

void main() {
  group('HillSimulation', () {
    test('sole_occupant_accumulates_one_second_over_60_ticks', () {
      final sim = HillSimulation(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1'],
      );
      sim.bodyOf('p1').setTransform(_onCrownTop(sim.map, 0), 0);

      for (var i = 0; i < 60; i++) {
        sim.tickInputs({'p1': _idle()});
      }

      expect(sim.holdSecondsOf('p1'), closeTo(1.0, 0.05));
    });

    test('contested_crown_accumulates_for_nobody', () {
      final sim = HillSimulation(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1', 'p2'],
      );
      sim.bodyOf('p1').setTransform(_onCrownTop(sim.map, -0.4), 0);
      sim.bodyOf('p2').setTransform(_onCrownTop(sim.map, 0.4), 0);

      for (var i = 0; i < 60; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }

      expect(sim.holdSecondsOf('p1'), 0.0);
      expect(sim.holdSecondsOf('p2'), 0.0);
    });

    test('occupancy_transitions_sole_contested_sole', () {
      final sim = HillSimulation(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1', 'p2'],
      );

      // Phase 1: p1 alone on the crown.
      sim.bodyOf('p1').setTransform(_onCrownTop(sim.map, 0), 0);
      for (var i = 0; i < 60; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }
      final afterSole = sim.holdSecondsOf('p1');
      expect(afterSole, closeTo(1.0, 0.05));

      // Phase 2: p2 joins — nobody accumulates.
      sim.bodyOf('p2').setTransform(_onCrownTop(sim.map, 0.3), 0);
      for (var i = 0; i < 60; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }
      expect(sim.holdSecondsOf('p1'), closeTo(afterSole, 0.05));
      expect(sim.holdSecondsOf('p2'), 0.0);

      // Phase 3: p2 leaves — p1 accumulates again.
      sim.bodyOf('p2').setTransform(Vector2(-5, 0.8), 0);
      for (var i = 0; i < 60; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }
      expect(sim.holdSecondsOf('p1'), closeTo(afterSole + 1.0, 0.1));
      expect(sim.holdSecondsOf('p2'), 0.0);
    });

    test('hold_samples_emit_every_10_ticks_last_sample_wins', () {
      final sim = HillSimulation(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      sim.bodyOf('p1').setTransform(_onCrownTop(sim.map, 0), 0);

      for (var i = 0; i < 65; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }

      final p1Samples = events
          .whereType<HoldTimeSample>()
          .where((s) => s.playerId == 'p1')
          .toList();
      final p2Samples = events
          .whereType<HoldTimeSample>()
          .where((s) => s.playerId == 'p2')
          .toList();

      // 65 ticks -> samples at ticks 10, 20, 30, 40, 50, 60.
      expect(p1Samples, hasLength(6));
      expect(p2Samples, hasLength(6));
      expect(p2Samples.last.seconds, 0.0);

      // p1's samples are non-decreasing; the last one carries ~1 s.
      for (var i = 1; i < p1Samples.length; i++) {
        expect(
          p1Samples[i].seconds,
          greaterThan(p1Samples[i - 1].seconds),
        );
      }
      expect(p1Samples.last.seconds, closeTo(1.0, 0.05));
    });

    test('falling_off_the_floor_respawns_on_main_floor', () {
      final sim = HillSimulation(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(
            Vector2(sim.map.floor.width / 2 + 1, 0.8),
            0,
          );

      _runUntil(sim, {'p1': _idle()}, () => events.any((e) => e is PlayerFell));

      final falls = events.whereType<PlayerFell>().toList();
      expect(falls, hasLength(1));
      expect(falls.single.playerId, 'p1');

      final spawn = sim.map.spawnPoints.first;
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(spawn.x, 0.4));
      expect(position.y, closeTo(spawn.y, 0.3));
    });

    test('timeout_ticks_mark_round_complete', () {
      final sim = HillSimulation.forTesting(
        map: HillArenaMap.kingOfTheHill(7),
        playerIds: ['p1', 'p2'],
        stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
        timeoutTicks: 30,
      );

      expect(sim.isComplete, isFalse);
      for (var i = 0; i < 29; i++) {
        sim.tickInputs({'p1': _idle()});
      }
      expect(sim.isComplete, isFalse);
      sim.tickInputs({'p1': _idle()});
      expect(sim.isComplete, isTrue);
    });

    test('crown_platform_is_climbable_by_jump_and_move', () {
      final map = HillArenaMap.kingOfTheHill(7);
      final sim = HillSimulation(map: map, playerIds: ['p1']);
      final body = sim.bodyOf('p1');

      // Stage on the left inner ramp step near the platform edge,
      // settle, then one jump tap with a short right burst. The
      // ~1.2 m jump apex clears the remaining height to the 1.0 m
      // crown top and the small drift lands the player on the crown
      // zone (physics proof the platform is reachable by plain
      // jump + move inputs, no teleport).
      final leftEdge = map.crownCenter.x - map.crownRadius;
      final leftInnerStep = map.ramps[1];
      final stepTop =
          leftInnerStep.center.y + leftInnerStep.height / 2;
      body.setTransform(Vector2(leftEdge - 0.35, stepTop + 0.76 + 0.01), 0);
      for (var i = 0; i < 10; i++) {
        sim.tickInputs({'p1': _idle()});
      }

      for (var i = 0; i < 6; i++) {
        sim.tickInputs({
          'p1': PlayerInputState(
            moveDir: Vector2(1, 0),
            jumpPressed: i == 0,
          ),
        });
      }

      var climbed = false;
      for (var i = 0; i < _maxTicks; i++) {
        sim.tickInputs({'p1': _idle()});
        if (sim.holdSecondsOf('p1') > 0) {
          climbed = true;
          break;
        }
      }

      expect(climbed, isTrue, reason: 'player never held the crown');
    });

    test('default_timeout_matches_gdd_75_seconds', () {
      expect(HillSimulation.defaultTimeoutTicks, 4500);
    });
  });
}
