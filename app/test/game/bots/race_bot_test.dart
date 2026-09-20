import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

/// Standing player center height on a platform whose top is at
/// y = 0 (matches CourseMap.trapRace anchor height).
const _standY = 0.76;

BotObservation _obs(
  int tick,
  double x, {
  double y = _standY,
  double vx = 4,
  bool grounded = true,
}) {
  return BotObservation(
    tick: tick,
    self: (x: x, y: y, vx: vx, vy: 0),
    grounded: grounded,
  );
}

void main() {
  final map = CourseMap.trapRace(1);
  final firstGap = _gaps(map).first;
  // Two-slab step map (0 m ground, then a 1 m lane): isolates the
  // ascending-step rule from hammers, walls and gaps.
  final stepMap = CourseMap(
    mapSeed: 0,
    spawnPoint: Vector2(3, 0.76),
    checkpoints: const [],
    finishLine: BoxSpec(center: Vector2(19.7, 1), width: 0.6, height: 3),
    killY: -6,
    platforms: [
      BoxSpec(center: Vector2(3, -0.5), width: 6, height: 1),
      BoxSpec(center: Vector2(9.5, 0.5), width: 7, height: 1),
    ],
    walls: const [],
    hammers: const [],
  );
  const stepEdge = 6.0;

  test('runs_right_at_full_input_on_open_ground', () {
    final bot = RaceBot.fromCourseMap(map);

    final input = bot.decide(_obs(0, 6));

    expect(input.moveDir.x, greaterThan(0.9));
    expect(input.jumpPressed, isFalse);
    expect(input.dashPressed, isFalse);
  });

  test('jumps_when_a_hammer_column_enters_the_look_ahead', () {
    final bot = RaceBot.fromCourseMap(map);
    final column =
        map.hammers.first.pivot.x -
        map.hammers.first.radius * RaceBot.hammerZoneFraction;

    final input = bot.decide(_obs(0, column - 2));

    expect(input.jumpPressed, isTrue);
    expect(input.moveDir.x, greaterThan(0.9));
  });

  test('jumps_when_a_gap_enters_the_look_ahead', () {
    final bot = RaceBot.fromCourseMap(map);

    final input = bot.decide(_obs(0, firstGap.minX - 2));

    expect(input.jumpPressed, isTrue);
  });

  test('jumps_onto_an_ascending_platform_step', () {
    final bot = RaceBot.fromCourseMap(stepMap);

    final near = bot.decide(_obs(0, stepEdge - 2));
    final far = bot.decide(_obs(0, stepEdge - 3.2));

    expect(
      near.jumpPressed,
      isTrue,
      reason: 'the 1 m step needs a jump before its face',
    );
    expect(
      far.jumpPressed,
      isFalse,
      reason: 'no jump before the step enters the look-ahead window',
    );
  });

  test('idles_with_zero_input_past_the_finish_line', () {
    final bot = RaceBot.fromCourseMap(map);
    final finishX = map.finishLine.center.x;

    final input = bot.decide(_obs(0, finishX + 1, vx: 0));

    expect(input.moveDir.x, 0);
    expect(input.moveDir.y, 0);
    expect(input.jumpPressed, isFalse);
    expect(input.dashPressed, isFalse);
  });

  test('stuck_runner_jump_dashes_after_the_threshold_ticks', () {
    final bot = RaceBot.fromCourseMap(map);
    // x = 8: past the back wall, no gap/step/hammer within the 2.5 m
    // look-ahead (the first gap sits past 17) — only the stuck rule
    // can fire.
    final outputs = [
      for (var t = 0; t < 35; t++) bot.decide(_obs(t, 8, vx: 0.2)),
    ];

    expect(outputs[10].jumpPressed, isFalse);
    expect(outputs[10].dashPressed, isFalse);
    expect(outputs[29].jumpPressed, isTrue, reason: 'stuck threshold');
    expect(outputs[29].dashPressed, isTrue, reason: 'stuck threshold');
  });
}

typedef _XRange = ({double minX, double maxX});

List<_XRange> _gaps(CourseMap map) {
  final sorted = [...map.platforms]
    ..sort((a, b) => a.center.x.compareTo(b.center.x));
  final gaps = <_XRange>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final left = sorted[i].center.x + sorted[i].width / 2;
    final right = sorted[i + 1].center.x - sorted[i + 1].width / 2;
    if (left < right) {
      gaps.add((minX: left, maxX: right));
    }
  }
  return gaps;
}
