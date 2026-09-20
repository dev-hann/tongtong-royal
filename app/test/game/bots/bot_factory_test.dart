import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/bot_factory.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/bots/survival_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raceMap = CourseMap.trapRace(1);
  final arenaMap = HammerArenaMap.hammerArena(1);

  group('buildBotRoster (GDD 9.1 fill policy)', () {
    test('fills_empty_seats_to_seat_target_capped_by_identity_pool', () {
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

    test('four_humans_yield_no_bots', () {
      expect(BotFactory.buildBotRoster(4), isEmpty);
    });

    test('custom_seat_target_is_honored', () {
      final roster = BotFactory.buildBotRoster(1, seatTarget: 3);
      expect(roster.length, 2);
      expect(roster.last.id, 'bot-2');
    });

    test('negative_or_over_target_human_counts_are_rejected', () {
      expect(() => BotFactory.buildBotRoster(-1), throwsArgumentError);
      expect(() => BotFactory.buildBotRoster(5), throwsArgumentError);
    });
  });

  group('forGame dispatch', () {
    test('maps_the_race_minigame_id_to_the_race_brain', () {
      expect(
        BotFactory.forGame('trap_race', seed: 1, map: raceMap),
        isA<RaceBot>(),
      );
    });

    test('maps_the_hammer_minigame_id_to_the_survival_brain', () {
      expect(
        BotFactory.forGame('hammer_dodge', seed: 1, map: arenaMap),
        isA<SurvivalBot>(),
      );
    });

    test('same_seed_hammer_bots_decide_identically', () {
      final a = BotFactory.forGame('hammer_dodge', seed: 9, map: arenaMap);
      final b = BotFactory.forGame('hammer_dodge', seed: 9, map: arenaMap);
      const obs = BotObservation(
        tick: 0,
        self: (x: 5, y: 1, vx: 0, vy: 0),
      );

      expect(a.decide(obs).moveDir.x, b.decide(obs).moveDir.x);
    });

    test('unknown_minigame_id_throws_argument_error', () {
      expect(
        () => BotFactory.forGame('nonsense', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });

    test('removed_king_of_the_hill_id_throws_argument_error', () {
      expect(
        () => BotFactory.forGame('king_of_the_hill', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });

    test('map_type_mismatched_with_the_minigame_throws_argument_error', () {
      expect(
        () => BotFactory.forGame('trap_race', seed: 1, map: 'not a map'),
        throwsArgumentError,
      );
      expect(
        () => BotFactory.forGame('hammer_dodge', seed: 1, map: raceMap),
        throwsArgumentError,
      );
    });
  });
}
