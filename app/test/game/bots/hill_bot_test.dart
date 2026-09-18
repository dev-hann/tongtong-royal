import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/hill_bot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final map = HillArenaMap.kingOfTheHill(1);
  final crownX = map.crownCenter.x;
  final crownTopY = map.crownTopY;

  test('on the floor below the crown: moves toward crown center x', () {
    final bot = HillBot.fromArenaMap(map);

    final input = bot.decide(
      BotObservation(tick: 0, self: (x: crownX - 3, y: 0.76, vx: 0, vy: 0)),
    );

    expect(input.moveDir.x, greaterThan(0.5));
  });

  test('on the crown alone: holds position (no move, no jump, no dash)', () {
    final bot = HillBot.fromArenaMap(map);

    final input = bot.decide(
      BotObservation(
        tick: 0,
        self: (x: crownX, y: crownTopY + 0.76, vx: 0, vy: 0),
      ),
    );

    expect(input.moveDir.x, 0);
    expect(input.jumpPressed, isFalse);
    expect(input.dashPressed, isFalse);
  });

  test('crown contested by nearby occupant: dashes at nearest occupant', () {
    final bot = HillBot.fromArenaMap(map);

    final input = bot.decide(
      BotObservation(
        tick: 0,
        self: (x: crownX, y: crownTopY + 0.76, vx: 0, vy: 0),
        nearbyPlayers: [(x: crownX + 0.5, y: crownTopY + 0.76, vx: 0, vy: 0)],
      ),
    );

    expect(input.dashPressed, isTrue);
    expect(input.moveDir.x, greaterThan(0));
  });

  test('ramp step ahead while climbing: jumps toward the crown', () {
    final bot = HillBot.fromArenaMap(map);
    // Outer ramp box spans [crownX + 2.7, crownX + 3.9]; bot stands
    // 0.7 m before its left face, below its top.
    final input = bot.decide(
      BotObservation(tick: 0, self: (x: crownX + 2, y: 0.76, vx: 0, vy: 0)),
    );

    expect(input.jumpPressed, isTrue);
    expect(input.moveDir.x, lessThan(-0.5));
  });
}
