import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('open ground: runs right at full input, no jump', () {
    final bot = RaceBot.fromCourseMap(map);

    final input = bot.decide(_obs(0, 0));

    expect(input.moveDir.x, greaterThan(0.9));
    expect(input.jumpPressed, isFalse);
    expect(input.dashPressed, isFalse);
  });

  test('wall obstacle ahead within look-ahead: jumps while running', () {
    final bot = RaceBot.fromCourseMap(map);
    // Back wall sits at x in [-3.3, -3.0]; 2.2 m ahead of the bot.
    final input = bot.decide(_obs(0, -5.5));

    expect(input.jumpPressed, isTrue);
    expect(input.moveDir.x, greaterThan(0.9));
  });

  test('gap ahead within look-ahead: jumps', () {
    final bot = RaceBot.fromCourseMap(map);
    // First gap spans x in [3, 6]; bot 2 m before its edge.
    final input = bot.decide(_obs(0, 1));

    expect(input.jumpPressed, isTrue);
  });

  test('finish line passed: idles with zero input', () {
    final bot = RaceBot.fromCourseMap(map);
    final finishX = map.finishLine.center.x;

    final input = bot.decide(_obs(0, finishX + 1, vx: 0));

    expect(input.moveDir.x, 0);
    expect(input.moveDir.y, 0);
    expect(input.jumpPressed, isFalse);
    expect(input.dashPressed, isFalse);
  });

  test('stuck (slow vx despite input): jump + dash after threshold ticks', () {
    final bot = RaceBot.fromCourseMap(map);
    // x = -2: no wall (wall maxX -3.0 < x), no gap (gap start 3 is 5 m
    // ahead), no hammer nearby — only the stuck rule can fire.
    final outputs = [
      for (var t = 0; t < 35; t++) bot.decide(_obs(t, -2, vx: 0.2)),
    ];

    expect(outputs[10].jumpPressed, isFalse);
    expect(outputs[10].dashPressed, isFalse);
    expect(outputs[29].jumpPressed, isTrue, reason: 'stuck threshold');
    expect(outputs[29].dashPressed, isTrue, reason: 'stuck threshold');
  });
}
