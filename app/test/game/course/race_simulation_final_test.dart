// FINAL-variant suite for RaceSimulation (`trap_race_final`,
// trap-race.md § FINAL). Separate file so the grandfathered
// prose-named race_simulation_test.dart stays untouched (testing
// doc § 10 carve-outs).
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Generous tick budget: two hammer revolutions plus travel.
const int _maxTicks = 4800;

PlayerInputState _run() => PlayerInputState(moveDir: Vector2(1, 0));

PlayerInputState _idle() => PlayerInputState();

RaceSimulation _finalSim({
  List<String> players = const ['p1', 'p2'],
  int starters = 2,
  int finalTimeoutTicks = RaceSimulation.defaultFinalTimeoutTicks,
}) {
  return RaceSimulation.forTesting(
    map: CourseMap.trapRaceFinal(7, starters),
    playerIds: players,
    stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
    variant: RaceVariant.finalRound,
    finalTimeoutTicks: finalTimeoutTicks,
  );
}

/// Runs [sim] until [isDone] holds after a tick.
void _runUntil(
  RaceSimulation sim,
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

void main() {
  group('RaceSimulation FINAL variant', () {
    test('fall_eliminates_without_respawn_events', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Park p2 on the finish platform (out of p1's runway), then
      // run p1 into the first gap without jumping.
      final finishX = sim.map.finishLine.center.x;
      sim.bodyOf('p2').setTransform(Vector2(finishX - 1.5, 1), 0);
      _runUntil(sim, {'p1': _run(), 'p2': _idle()}, () => !sim.isAlive('p1'));

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(1));
      expect(eliminations.single.playerId, 'p1');
      expect(events.whereType<PlayerFell>(), isEmpty);
      expect(sim.isAlive('p2'), isTrue);
    });

    test('eliminated_body_is_destroyed_after_a_fall', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      final finishX = sim.map.finishLine.center.x;
      sim.bodyOf('p2').setTransform(Vector2(finishX - 1.5, 1), 0);
      _runUntil(sim, {'p1': _run(), 'p2': _idle()}, () => !sim.isAlive('p1'));

      expect(() => sim.bodyOf('p1'), throwsStateError);
      expect(sim.poseOf('p1'), isNull);
      expect(
        sim.poseOf('p2')!.x,
        closeTo(finishX - 1.5, 0.5),
        reason: 'p2 stays parked on the finish platform',
      );
    });

    test('hammer_contact_eliminates', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      final finishX = sim.map.finishLine.center.x;
      sim.bodyOf('p2').setTransform(Vector2(finishX - 1.5, 1), 0);

      // Park p1 in the first hammer's sweep column (the arm rotates
      // about its pivot and its tip grazes the surface); the
      // 1.6 rad/s arm must sweep through within one revolution.
      final hammer = sim.map.hammers.first;
      sim.bodyOf('p1').setTransform(Vector2(hammer.pivot.x, 1), 0);
      _runUntil(
        sim,
        {'p1': _idle(), 'p2': _idle()},
        () => !sim.isAlive('p1') || sim.isComplete,
      );

      expect(sim.isAlive('p1'), isFalse);
      expect(events.whereType<PlayerEliminated>(), isNotEmpty);
    });

    test('first_finisher_completes_the_round_instantly', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Clear run-up for p1 onto the finish sensor; p2 parked mid
      // course (alive, unfinished).
      final finishX = sim.map.finishLine.center.x;
      final p8Left = finishX - sim.map.platforms.last.width;
      sim.bodyOf('p1').setTransform(Vector2(p8Left + 0.2, 1), 0);
      sim.bodyOf('p2').setTransform(Vector2(p8Left - 5, 1), 0);

      _runUntil(sim, {'p1': _run(), 'p2': _idle()}, () => sim.isComplete);

      expect(events.whereType<PlayerFinished>(), hasLength(1));
      expect(events.whereType<PlayerFinished>().single.playerId, 'p1');
      final finishTick = events.whereType<PlayerFinished>().single.tick;

      sim.tickInputs({'p1': _idle(), 'p2': _run()});

      expect(events.whereType<PlayerFinished>().single.tick, finishTick);
    });

    test('last_alive_survivor_completes_when_others_fall', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p2').setTransform(
        Vector2(0, sim.map.killY - 5),
        0,
      );
      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      expect(sim.isAlive('p2'), isFalse);
      expect(sim.isAlive('p1'), isTrue);
      expect(sim.isComplete, isTrue, reason: 'one alive ends the FINAL');
    });

    test('same_tick_double_fall_completes_with_both_events', () {
      final sim = _finalSim();
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(
        Vector2(0, sim.map.killY - 5),
        0,
      );
      sim.bodyOf('p2').setTransform(
        Vector2(0, sim.map.killY - 5),
        0,
      );
      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(2));
      expect(eliminations.first.tick, equals(eliminations.last.tick));
      expect(sim.isComplete, isTrue);
    });

    test('timeout_completes_with_both_alive', () {
      final sim = _finalSim(finalTimeoutTicks: 90);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Both idle against the back wall: no falls, no finishes.
      for (var i = 0; i < 90; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }

      expect(sim.isComplete, isTrue);
      expect(sim.isAlive('p1'), isTrue);
      expect(sim.isAlive('p2'), isTrue);
      expect(events, isEmpty);
    });

    test('spawn_slots_stay_on_the_start_platform', () {
      for (final count in [2, 4]) {
        final players = [
          for (var i = 1; i <= count; i++) 'p$i',
        ];
        final sim = _finalSim(players: players, starters: count);

        for (final id in players) {
          final pose = sim.poseOf(id)!;
          expect(
            pose.x,
            inInclusiveRange(0, 2.4),
            reason: '$count starters: spawn on the start platform',
          );
        }
      }
    });

    test('spawn_slots_are_distinct_per_starter', () {
      for (final count in [2, 4]) {
        final players = [
          for (var i = 1; i <= count; i++) 'p$i',
        ];
        final sim = _finalSim(players: players, starters: count);

        final xs = <double>{
          for (final id in players) sim.poseOf(id)!.x,
        };
        expect(xs, hasLength(count), reason: '$count starters distinct');
      }
    });

    test('standard_mode_fall_still_respawns_without_elimination', () {
      final sim = RaceSimulation.forTesting(
        map: CourseMap.trapRace(7),
        playerIds: const ['p1'],
        stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Run into the first gap without jumping: standard mode
      // respawns (PlayerFell), never eliminates.
      _runUntil(
        sim,
        {'p1': _run()},
        () => events.whereType<PlayerFell>().isNotEmpty,
      );

      expect(sim.isAlive('p1'), isTrue);
      expect(events.whereType<PlayerEliminated>(), isEmpty);
      expect(sim.isComplete, isFalse);
    });
  });
}
