import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/survival_bot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final map = HammerArenaMap.hammerArena(1);

  BotObservation obs(
    int tick,
    double x,
    double y, {
    List<({double x, double y, double angle, double angularVelocity})> hazards =
        const [],
  }) {
    return BotObservation(
      tick: tick,
      self: (x: x, y: y, vx: 0, vy: 0),
      nearbyHazards: hazards,
    );
  }

  test('far from center: steers inward at full input', () {
    final bot = SurvivalBot.fromArenaMap(map, seed: 1);

    final input = bot.decide(obs(0, 5, 1));

    expect(input.moveDir.x, lessThan(-0.9));
  });

  test('arm tip predicted to sweep bot position: jumps', () {
    final bot = SurvivalBot.fromArenaMap(map, seed: 1);
    // Bot at polar angle atan2(1, 3) ~ 0.32 rad, radius ~3.16 m —
    // inside both arms' sweep discs. Arm 0.3 rad behind and closing
    // at 2 rad/s reaches the bot in 0.15 s (9 ticks < horizon).
    final theta = math.atan2(1, 3);

    final input = bot.decide(
      obs(
        0,
        3,
        1,
        hazards: [(x: 0, y: 0, angle: theta - 0.3, angularVelocity: 2)],
      ),
    );

    expect(input.jumpPressed, isTrue);
  });

  test('arm closing too slowly: no jump', () {
    final bot = SurvivalBot.fromArenaMap(map, seed: 1);
    final theta = math.atan2(1, 3);

    final input = bot.decide(
      obs(
        0,
        3,
        1,
        hazards: [(x: 0, y: 0, angle: theta - 0.3, angularVelocity: 0.4)],
      ),
    );

    expect(input.jumpPressed, isFalse);
  });

  test('arm rotating away from bot: no jump', () {
    final bot = SurvivalBot.fromArenaMap(map, seed: 1);
    final theta = math.atan2(1, 3);

    // Arm 0.3 rad "behind" the bot but turning clockwise (away):
    // it next meets the bot's angle only after ~2 pi of sweep.
    final input = bot.decide(
      obs(
        0,
        3,
        1,
        hazards: [(x: 0, y: 0, angle: theta - 0.3, angularVelocity: -2)],
      ),
    );

    expect(input.jumpPressed, isFalse);
  });

  test('centered, no threat: idle (move bounded by wander amplitude)', () {
    final bot = SurvivalBot.fromArenaMap(map, seed: 1);

    final input = bot.decide(obs(0, 0.5, 1));

    expect(
      input.moveDir.x.abs(),
      lessThanOrEqualTo(SurvivalBot.wanderAmplitude),
    );
    expect(input.jumpPressed, isFalse);
  });
}
