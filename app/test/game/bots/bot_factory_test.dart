import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raceMap = CourseMap.trapRace(1);

  group('buildBotRoster (GDD 9.1 fill policy)', () {
    test('fills empty seats to the seat target, capped by identity pool', () {
      // 0 humans is unreachable in practice (the host is human) but
      // must not crash: the bot-1..bot-3 identity pool caps it at 3.
      final cases = <(int, int)>[(0, 3), (1, 3), (2, 2), (3, 1)];
      for (final (humans, expectedBots) in cases) {
        final roster = BotFactory.buildBotRoster(humans);
        expect(roster.length, expectedBots, reason: '$humans humans');
        expect(humans + roster.length, lessThanOrEqualTo(4));
        for (var i = 0; i < roster.length; i++) {
          expect(roster[i].id, 'bot-${i + 1}');
          expect(roster[i].nickname, 'BOT ${i + 1}');
        }
      }
    });

    test('4 humans: no bots', () {
      expect(BotFactory.buildBotRoster(4), isEmpty);
    });

    test('custom seat target is honored', () {
      final roster = BotFactory.buildBotRoster(1, seatTarget: 3);
      expect(roster.length, 2);
      expect(roster.last.id, 'bot-2');
    });

    test('negative or over-target human counts are rejected', () {
      expect(() => BotFactory.buildBotRoster(-1), throwsArgumentError);
      expect(() => BotFactory.buildBotRoster(5), throwsArgumentError);
    });
  });

  group('forGame dispatch', () {
    test('maps the race minigame id to the race brain', () {
      expect(
        BotFactory.forGame('trap_race', seed: 1, map: raceMap),
        isA<RaceBot>(),
      );
    });

    test('unknown minigame id: ArgumentError', () {
      expect(
        () => BotFactory.forGame('nonsense', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });

    test('removed king_of_the_hill id: ArgumentError', () {
      expect(
        () => BotFactory.forGame('king_of_the_hill', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });

    test('removed hammer_dodge id: ArgumentError', () {
      expect(
        () => BotFactory.forGame('hammer_dodge', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });

    test('map type mismatched with the minigame: ArgumentError', () {
      expect(
        () => BotFactory.forGame('trap_race', seed: 1, map: 'not a map'),
        throwsArgumentError,
      );
    });
  });
}
