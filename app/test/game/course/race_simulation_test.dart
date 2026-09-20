import 'dart:math' as math;

import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless race fixtures: fixed-dt stepping only, no wall clock
/// (testing doc § 4). Generous tick budgets keep the tests robust
/// against solver jitter without timing assertions.
const int _maxTicks = 5400;

/// Standing player center height on a platform whose top is at
/// y = 0 (matches CourseMap.trapRace anchor height).
const double _standY = 0.76;

PlayerInputState _right() => PlayerInputState(moveDir: Vector2(1, 0));
PlayerInputState _left() => PlayerInputState(moveDir: Vector2(-1, 0));
PlayerInputState _idle() => PlayerInputState();
PlayerInputState _runJump() =>
    PlayerInputState(moveDir: Vector2(1, 0), jumpPressed: true);

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

/// Pit gaps between consecutive platforms, ascending x.
List<({double minX, double maxX})> _gaps(CourseMap map) {
  final sorted = [...map.platforms]
    ..sort((a, b) => a.center.x.compareTo(b.center.x));
  final gaps = <({double minX, double maxX})>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final left = sorted[i].center.x + sorted[i].width / 2;
    final right = sorted[i + 1].center.x - sorted[i + 1].width / 2;
    if (left < right) {
      gaps.add((minX: left, maxX: right));
    }
  }
  return gaps;
}

/// The elevated safe lane platform (top y = 1).
BoxSpec _elevatedLane(CourseMap map) =>
    map.platforms.where((p) => p.center.y + p.height / 2 > 0.5).single;

void main() {
  group('RaceSimulation standard mode', () {
    test('falling_before_any_checkpoint_respawns_at_the_spawn_point', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Run right from the spawn into the first pit gap without
      // jumping.
      _runUntil(sim, _right(), () => events.any((e) => e is PlayerFell));

      final falls = events.whereType<PlayerFell>().toList();
      expect(falls, hasLength(1));
      expect(falls.single.playerId, 'p1');
      expect(falls.single.tick, greaterThan(0));

      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(sim.map.spawnPoint.x, 0.4));
      expect(position.y, closeTo(sim.map.spawnPoint.y, 0.3));
    });

    test('falling_after_checkpoint_one_respawns_there', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Drop onto the platform past the first gap, settle on
      // checkpoint 1, then walk back into the gap.
      final checkpoint1 = sim.map.checkpoints.first;
      sim.bodyOf('p1').setTransform(checkpoint1.clone(), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }

      _runUntil(sim, _left(), () => events.any((e) => e is PlayerFell));

      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(checkpoint1.x, 0.4));
      expect(position.y, closeTo(checkpoint1.y, 0.3));
    });

    test('checkpoints_trigger_in_any_order_respawn_keeps_the_highest', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Touch checkpoint 3 (index 2) first, then the lower checkpoint
      // 1 (index 0), then fall — respawn must use checkpoint 3.
      sim.bodyOf('p1').setTransform(sim.map.checkpoints[2].clone(), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }
      sim.bodyOf('p1').setTransform(sim.map.checkpoints[0].clone(), 0);
      for (var i = 0; i < 10; i++) {
        sim.tick('p1', _idle());
      }

      // Walk left off the gap-lane platform into the first gap.
      _runUntil(sim, _left(), () => events.any((e) => e is PlayerFell));

      final checkpoint3 = sim.map.checkpoints[2];
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(checkpoint3.x, 0.4));
      expect(position.y, closeTo(checkpoint3.y, 0.3));
    });

    test('crossing_the_finish_emits_player_finished_with_tick_and_player', () {
      final sim = RaceSimulation(map: CourseMap.trapRace(7), playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Stand short of the finish line on the last platform, run
      // right.
      final finish = sim.map.finishLine.center;
      final lastTop = sim.map.platforms
          .map((p) => p.center.y + p.height / 2)
          .reduce((a, b) => a < b ? a : b);
      sim.bodyOf('p1').setTransform(Vector2(finish.x - 2, lastTop + 0.76), 0);
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

    test('players_touching_the_finish_on_the_same_tick_share_the_tick', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      final finish = sim.map.finishLine.center;
      final lastTop = sim.map.platforms
          .map((p) => p.center.y + p.height / 2)
          .reduce((a, b) => a < b ? a : b);
      sim.bodyOf('p1').setTransform(Vector2(finish.x - 0.1, lastTop + 0.76), 0);
      sim.bodyOf('p2').setTransform(Vector2(finish.x + 0.1, lastTop + 0.76), 0);

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

    test('active_input_without_displacement_respawns_without_a_fall', () {
      final sim = RaceSimulation.forTesting(
        map: CourseMap.trapRace(7),
        playerIds: ['p1'],
        stuckThresholdSeconds: 0.5,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Run left into the start back wall (the player pins at the
      // wall face just left of the origin): input stays active
      // while displacement stalls, so only stuck detection can
      // respawn.
      var reachedWall = false;
      for (var i = 0; i < _maxTicks; i++) {
        sim.tick('p1', _left());
        final x = sim.bodyOf('p1').position.x;
        if (x < 0.6) {
          reachedWall = true;
        }
        if (reachedWall && x > 2) {
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

  group('RaceSimulation standard course hazards (trap-race.md)', () {
    test('pit_gaps_are_crossable_with_a_single_timed_jump', () {
      final map = CourseMap.trapRace(7);
      final sim = RaceSimulation(map: map, playerIds: ['p1']);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (final gap in _gaps(map)) {
        sim.bodyOf('p1').setTransform(Vector2(gap.minX - 2.2, _standY), 0);
        for (var i = 0; i < 5; i++) {
          sim.tick('p1', _idle());
        }

        sim.tick('p1', _runJump());
        var crossed = false;
        for (var i = 0; i < 300 && !crossed; i++) {
          sim.tick('p1', _right());
          crossed = sim.bodyOf('p1').position.x > gap.maxX + 1;
        }

        expect(
          crossed,
          isTrue,
          reason: 'gap [${gap.minX}, ${gap.maxX}] must be jumpable',
        );
        expect(
          events.whereType<PlayerFell>(),
          isEmpty,
          reason: 'gap [${gap.minX}, ${gap.maxX}] crossing must not fall',
        );
      }
    });

    test('elevated_safe_lane_is_reachable_by_jump_from_the_ground', () {
      final map = CourseMap.trapRace(7);
      final sim = RaceSimulation(map: map, playerIds: ['p1']);
      final lane = _elevatedLane(map);
      final laneLeft = lane.center.x - lane.width / 2;
      final laneRight = lane.center.x + lane.width / 2;

      sim.bodyOf('p1').setTransform(Vector2(laneLeft - 2.2, _standY), 0);
      for (var i = 0; i < 5; i++) {
        sim.tick('p1', _idle());
      }

      sim.tick('p1', _runJump());
      var crossed = false;
      var stoodOnLane = false;
      for (var i = 0; i < 300 && !crossed; i++) {
        sim.tick('p1', _right());
        final position = sim.bodyOf('p1').position;
        if (position.x > laneLeft + 0.3 && position.x < laneRight - 0.3) {
          stoodOnLane = stoodOnLane || position.y > 1.5;
        }
        crossed = position.x > laneRight + 1;
      }

      expect(crossed, isTrue, reason: 'runner must cross the alley');
      expect(
        stoodOnLane,
        isTrue,
        reason: 'the jump must land the runner on the 1 m lane',
      );
    });

    test('elevated_safe_lane_is_never_swept_by_the_hammers', () {
      final map = CourseMap.trapRace(7);
      final sim = RaceSimulation(map: map, playerIds: ['p1']);
      final lane = _elevatedLane(map);
      sim.bodyOf('p1').setTransform(Vector2(lane.center.x, 1 + _standY), 0);

      // Two full arm revolutions at 1.2 rad/s (trap-race.md § Level
      // design): a struck runner would be flung off its spot.
      const revolutions = 2;
      final ticks = (revolutions * 2 * math.pi / 1.2 * PhysicsConsts.tickRate)
          .ceil();
      final startX = sim.bodyOf('p1').position.x;
      for (var i = 0; i < ticks; i++) {
        sim.tick('p1', _idle());
      }

      final position = sim.bodyOf('p1').position;
      expect(
        (position.x - startX).abs(),
        lessThan(0.05),
        reason: 'a swept runner would be knocked off the lane',
      );
      expect(sim.bodyOf('p1').position.y, greaterThan(1.4));
    });
  });

  group('RaceSimulation finish quota (GDD § 7.1)', () {
    test('round_completes_the_instant_the_quota_of_finishers_is_met', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: const ['p1', 'p2', 'p3', 'p4'],
        finishQuota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      _parkTwoAtTheFinish(sim);

      for (var i = 0; i < 600 && !sim.isComplete; i++) {
        sim.tickInputs({
          'p1': _right(),
          'p2': _right(),
          'p3': _idle(),
          'p4': _idle(),
        });
      }

      expect(sim.isComplete, isTrue, reason: 'two finishers meet the quota');
      expect(events.whereType<PlayerFinished>(), hasLength(2));
      expect(sim.hasFinished('p3'), isFalse);
      expect(sim.hasFinished('p4'), isFalse);
    });

    test('completed_quota_round_ignores_later_finishers', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: const ['p1', 'p2', 'p3', 'p4'],
        finishQuota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      _parkTwoAtTheFinish(sim);

      for (var i = 0; i < 600 && !sim.isComplete; i++) {
        sim.tickInputs({
          'p1': _right(),
          'p2': _right(),
          'p3': _idle(),
          'p4': _idle(),
        });
      }

      sim.tickInputs({
        'p1': _idle(),
        'p2': _idle(),
        'p3': _right(),
        'p4': _right(),
      });

      expect(events.whereType<PlayerFinished>(), hasLength(2));
    });

    test('round_stays_open_below_the_quota_even_with_finishers', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: const ['p1', 'p2', 'p3', 'p4'],
        finishQuota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      _parkTwoAtTheFinish(sim);

      // Only p1 runs to the finish; the quota of two is not met.
      for (
        var i = 0;
        i < 600 && events.whereType<PlayerFinished>().isEmpty;
        i++
      ) {
        sim.tickInputs({
          'p1': _right(),
          'p2': _idle(),
          'p3': _idle(),
          'p4': _idle(),
        });
      }

      expect(events.whereType<PlayerFinished>(), hasLength(1));
      expect(sim.isComplete, isFalse);
    });

    test('default_quota_waits_for_every_finisher', () {
      final sim = RaceSimulation(
        map: CourseMap.trapRace(7),
        playerIds: const ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      _parkTwoAtTheFinish(sim);

      for (
        var i = 0;
        i < 600 && events.whereType<PlayerFinished>().isEmpty;
        i++
      ) {
        sim.tickInputs({'p1': _right(), 'p2': _idle()});
      }

      expect(sim.hasFinished('p1'), isTrue);
      expect(sim.isComplete, isFalse, reason: 'p2 has not finished yet');
    });
  });

  group('RaceSimulation scripted completion', () {
    test('map_driven_bot_completes_the_standard_course', () {
      final map = CourseMap.trapRace(7);
      final sim = RaceSimulation.forTesting(
        map: map,
        playerIds: const ['p1'],
        stuckThresholdSeconds: 0.5,
      );
      final bot = RaceBot.fromCourseMap(map);
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      var finished = false;
      for (var t = 0; t < _maxTicks && !finished; t++) {
        final input = bot.decide(
          BotObservation(
            tick: t,
            self: (
              x: sim.bodyOf('p1').position.x,
              y: sim.bodyOf('p1').position.y,
              vx: sim.bodyOf('p1').linearVelocity.x,
              vy: sim.bodyOf('p1').linearVelocity.y,
            ),
            grounded: sim.bodyOf('p1').linearVelocity.y.abs() < 0.08,
          ),
        );
        sim.tickInputs({'p1': input});
        finished = sim.hasFinished('p1');
      }

      expect(finished, isTrue, reason: 'bot must finish within 90 s');
      expect(
        events.whereType<PlayerFell>().length,
        lessThanOrEqualTo(4),
        reason: 'a competent bot rarely falls (gaps misjudged rarely)',
      );
    });
  });
}

/// Parks p1 and p2 one step left of the finish sensor on the last
/// platform (both still unfinished).
void _parkTwoAtTheFinish(RaceSimulation sim) {
  final finish = sim.map.finishLine.center;
  final lastTop = sim.map.platforms
      .map((p) => p.center.y + p.height / 2)
      .reduce((a, b) => a < b ? a : b);
  sim.bodyOf('p1').setTransform(Vector2(finish.x - 1.4, lastTop + 0.76), 0);
  sim.bodyOf('p2').setTransform(Vector2(finish.x - 2.4, lastTop + 0.76), 0);
}
