import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless race fixtures: fixed-dt stepping only, no wall clock
/// (testing doc § 4). Generous tick budgets keep the tests robust
/// against solver jitter without timing assertions.
const int _maxTicks = 500;

PlayerInputState _right() => PlayerInputState(moveDir: Vector2(1, 0));
PlayerInputState _left() => PlayerInputState(moveDir: Vector2(-1, 0));
PlayerInputState _idle() => PlayerInputState();

/// Runs [sim] with [input] until [isDone] holds after a tick.
/// Fails the test if it never holds within [_maxTicks].
void _runUntil(
  RaceSimulation sim,
  PlayerInputState input,
  bool Function() isDone,
) {
  for (var i = 0; i < _maxTicks; i++) {
    sim.tick('p1', input);
    if (isDone()) {
      return;
    }
  }
  fail('condition never met within $_maxTicks ticks');
}

void main() {
  group('RaceSimulation', () {
    test('player falling off the start respawns at the spawn point', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      _runUntil(sim, _right(), () => events.any((e) => e is PlayerFell));

      final falls = events.whereType<PlayerFell>().toList();
      expect(falls, hasLength(1));
      expect(falls.single.playerId, 'p1');
      expect(falls.single.tick, greaterThan(0));

      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(sim.map.spawnPoint.x, 0.4));
      expect(position.y, closeTo(sim.map.spawnPoint.y, 0.3));
    });

    test('touching checkpoint 2 then falling respawns at checkpoint 2', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Drop in left of checkpoint 2 (platform C), then run right
      // through the checkpoint and off the far edge.
      sim.bodyOf('p1').setTransform(Vector2(16.8, 0.8), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }

      _runUntil(sim, _right(), () => events.any((e) => e is PlayerFell));

      final checkpoint2 = sim.map.checkpoints[1];
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(checkpoint2.x, 0.4));
      expect(position.y, closeTo(checkpoint2.y, 0.3));
    });

    test('checkpoints trigger in any order, respawn keeps the highest', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Touch checkpoint 3 (index 2) first, then the lower checkpoint 2
      // (index 1), then fall — respawn must use checkpoint 3.
      sim.bodyOf('p1').setTransform(sim.map.checkpoints[2].clone(), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }
      sim.bodyOf('p1').setTransform(sim.map.checkpoints[1].clone(), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }

      // Walk left off platform C into the gap.
      _runUntil(sim, _left(), () => events.any((e) => e is PlayerFell));

      final checkpoint3 = sim.map.checkpoints[2];
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(checkpoint3.x, 0.4));
      expect(position.y, closeTo(checkpoint3.y, 0.3));
    });

    test('crossing the finish emits PlayerFinished with tick and player', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Stand short of the finish line on the last platform, run right.
      sim.bodyOf('p1').setTransform(Vector2(26.8, 0.8), 0);
      for (var i = 0; i < 5; i++) {
        sim.tick('p1', _idle());
      }

      _runUntil(sim, _right(), () => sim.hasFinished('p1'));

      final finishes = events.whereType<PlayerFinished>().toList();
      expect(finishes, hasLength(1));
      expect(finishes.single.playerId, 'p1');
      expect(finishes.single.tick, sim.currentTick);
      expect(finishes.single.tick, greaterThan(0));
    });

    test('two players touching the finish on the same tick share the tick', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      final finish = sim.map.finishLine.center;
      sim.bodyOf('p1').setTransform(Vector2(finish.x - 0.1, 0.8), 0);
      sim.bodyOf('p2').setTransform(Vector2(finish.x + 0.1, 0.8), 0);

      for (var i = 0; i < 5; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }

      final finishes = events.whereType<PlayerFinished>().toList();
      expect(finishes, hasLength(2));
      expect(finishes.first.tick, finishes.last.tick);
      expect({finishes.first.playerId, finishes.last.playerId}, {'p1', 'p2'});
      expect(sim.hasFinished('p1'), isTrue);
      expect(sim.hasFinished('p2'), isTrue);
    });

    test('active input without displacement respawns (stuck, no fall)', () {
      final sim = RaceSimulation.forTesting(
        map: CourseMap.trapRace(7),
        playerIds: ['p1'],
        stuckThresholdSeconds: 0.5,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Run left into the start back wall: input stays active while
      // displacement stalls, so only stuck detection can respawn.
      var reachedWall = false;
      for (var i = 0; i < _maxTicks; i++) {
        sim.tick('p1', _left());
        final x = sim.bodyOf('p1').position.x;
        if (x < -2.5) {
          reachedWall = true;
        }
        if (reachedWall && x > -0.5) {
          break;
        }
      }

      expect(reachedWall, isTrue, reason: 'player never reached the wall');
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(sim.map.spawnPoint.x, 0.4));
      expect(position.y, closeTo(sim.map.spawnPoint.y, 0.3));
      expect(
        events.whereType<PlayerFell>(),
        isEmpty,
        reason: 'stuck respawn is not a fall',
      );
    });
  });
}
