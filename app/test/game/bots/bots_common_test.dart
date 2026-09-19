import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/bots/race_bot.dart';
import 'package:app/game/bots/survival_bot.dart';
import 'package:app/game/course/course_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  final raceMap = CourseMap.trapRace(1);
  final hammerMap = HammerArenaMap.hammerArena(1);

  List<PlayerInputState> runRace(RaceBot bot) {
    return [
      for (var t = 0; t < 100; t++)
        bot.decide(
          BotObservation(
            tick: t,
            self: (x: -2 + t * 0.1, y: 0.76, vx: t.isEven ? 0.1 : 5, vy: 0),
            grounded: t % 5 != 0,
          ),
        ),
    ];
  }

  List<PlayerInputState> runSurvival(SurvivalBot bot) {
    const selfX = 3.0;
    const selfY = 1.0;
    final theta = math.atan2(selfY, selfX);
    return [
      for (var t = 0; t < 100; t++)
        bot.decide(
          BotObservation(
            tick: t,
            self: (x: selfX, y: selfY, vx: 0, vy: 0),
            nearbyHazards: [
              (x: 0, y: 0, angle: theta - 1 + t * 0.02, angularVelocity: 1.3),
            ],
          ),
        ),
    ];
  }

  group('bot output sanitization', () {
    test('outputs stay finite and clamped on extreme poses', () {
      final brains = <BotBrain>[
        RaceBot.fromCourseMap(raceMap),
        SurvivalBot.fromArenaMap(hammerMap, seed: 7),
      ];
      const extremes = <({double x, double y, double vx, double vy})>[
        (x: 0, y: 0.76, vx: 4, vy: 0),
        (x: 1e9, y: 0.76, vx: 4, vy: 0),
        (x: -1e9, y: 0.76, vx: 4, vy: 0),
        (x: 0, y: 0.76, vx: 4, vy: 0),
        (x: 5, y: 1, vx: 4, vy: 0),
        (x: 3, y: 1, vx: 4, vy: 0),
      ];
      for (final brain in brains) {
        for (final pose in extremes) {
          final input = brain.decide(
            BotObservation(
              tick: 3,
              self: pose,
              nearbyHazards: const [
                (x: 0, y: 0, angle: 1, angularVelocity: 9),
                (x: 0, y: 0, angle: double.nan, angularVelocity: 9),
              ],
            ),
          );
          expect(input.moveDir.x.isFinite, isTrue);
          expect(input.moveDir.y.isFinite, isTrue);
          expect(input.moveDir.x, lessThanOrEqualTo(1));
          expect(input.moveDir.x, greaterThanOrEqualTo(-1));
        }
        final nanInput = brain.decide(
          const BotObservation(
            tick: 3,
            self: (x: double.nan, y: double.nan, vx: double.nan, vy: 0.0),
          ),
        );
        expect(nanInput.moveDir.x.isFinite, isTrue);
      }
    });
  });

  group('bot determinism', () {
    test(
      'same seed and observation stream give identical output (100 ticks)',
      () {
        void expectSequencesEqual(
          List<PlayerInputState> a,
          List<PlayerInputState> b,
        ) {
          expect(a.length, b.length);
          for (var i = 0; i < a.length; i++) {
            expect(a[i].moveDir.x, b[i].moveDir.x, reason: 'race tick $i x');
            expect(a[i].moveDir.y, b[i].moveDir.y, reason: 'race tick $i y');
            expect(a[i].jumpPressed, b[i].jumpPressed, reason: 'tick $i jump');
            expect(a[i].dashPressed, b[i].dashPressed, reason: 'tick $i dash');
          }
        }

        expectSequencesEqual(
          runRace(RaceBot.fromCourseMap(raceMap)),
          runRace(RaceBot.fromCourseMap(raceMap)),
        );
        expectSequencesEqual(
          runSurvival(SurvivalBot.fromArenaMap(hammerMap, seed: 42)),
          runSurvival(SurvivalBot.fromArenaMap(hammerMap, seed: 42)),
        );
      },
    );
  });
}
