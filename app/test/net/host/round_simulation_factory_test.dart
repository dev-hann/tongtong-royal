import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/net/host/round_simulation_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultRoundSimulationFactory', () {
    test('trap_race_builds_the_standard_race_simulation', () {
      final sim = defaultRoundSimulationFactory('trap_race', 7, const ['p1']);

      expect(sim, isA<RaceSimulation>());
      expect((sim as RaceSimulation).variant, RaceVariant.standard);
      expect(sim.map.checkpoints, isNotEmpty);
    });

    test('trap_race_binds_the_round_one_finish_quota', () {
      final sim = defaultRoundSimulationFactory(
        'trap_race',
        7,
        const ['p1', 'p2', 'p3', 'p4'],
      ) as RaceSimulation;

      expect(sim.finishQuota, 3, reason: 'R1 quota 3 (GDD § 4 schedule)');
    });

    test('trap_race_final_builds_the_final_variant_simulation', () {
      final sim = defaultRoundSimulationFactory(
        'trap_race_final',
        7,
        const ['p1', 'p2'],
      );

      expect(sim, isA<RaceSimulation>());
      expect((sim as RaceSimulation).variant, RaceVariant.finalRound);
      expect(sim.map.checkpoints, isEmpty);
      expect(sim.map.spawnPoints, hasLength(2));
    });

    test('trap_race_final_spread_matches_the_roster_size', () {
      final sim = defaultRoundSimulationFactory(
        'trap_race_final',
        7,
        const ['p1', 'p2', 'p3'],
      ) as RaceSimulation;

      expect(sim.map.spawnPoints, hasLength(3));
    });

    test('hammer_dodge_builds_the_hammer_simulation', () {
      final sim = defaultRoundSimulationFactory(
        'hammer_dodge',
        7,
        const ['p1', 'p2', 'p3'],
      );

      expect(sim, isA<HammerSimulation>());
      expect(sim.progressAnchorX, isNull);
      expect(sim.poseOf('p1')!.y, greaterThan(0));
    });

    test('hammer_dodge_quota_follows_the_show_schedule_round_two', () {
      final sim = defaultRoundSimulationFactory(
        'hammer_dodge',
        7,
        const ['p1', 'p2', 'p3'],
      ) as HammerSimulation;

      expect(sim.quota, 2);
    });

    test('unknown_minigame_id_throws_argument_error', () {
      expect(
        () => defaultRoundSimulationFactory('nonsense', 7, const ['p1']),
        throwsArgumentError,
      );
    });
  });
}
