import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

void main() {
  group('RaceSteering', () {
    test('auto_runs_right_at_full_deflection_without_jump', () {
      final decision = const RaceSteering().sample(
        const SteeringObservation(tick: 0, selfX: 0, selfY: 0),
      );

      expect(decision.moveDir.x, 1);
      expect(decision.moveDir.y, 0);
      expect(decision.jumpPressed, isFalse);
    });

    test('ignores_pose_noise_constant_right_regardless', () {
      final decision = const RaceSteering().sample(
        const SteeringObservation(tick: 99, selfX: 40, selfY: -3, selfVy: 5),
      );

      expect(decision.moveDir.x, 1);
      expect(decision.moveDir.y, 0);
    });
  });

  group('HammerSteering', () {
    test('seeks_center_from_beyond_the_right_band_edge', () {
      final decision = const HammerSteering().sample(
        const SteeringObservation(
          tick: 0,
          selfX: HammerSteering.centerBandMeters + 1,
          selfY: 0,
        ),
      );

      expect(decision.moveDir.x, -1);
      expect(decision.moveDir.y, 0);
    });

    test('seeks_center_from_beyond_the_left_band_edge', () {
      final decision = const HammerSteering().sample(
        const SteeringObservation(
          tick: 0,
          selfX: -HammerSteering.centerBandMeters - 1,
          selfY: 0,
        ),
      );

      expect(decision.moveDir.x, 1);
    });

    test('idles_zero_drift_inside_the_center_band', () {
      final decision = const HammerSteering().sample(
        const SteeringObservation(
          tick: 0,
          selfX: HammerSteering.centerBandMeters / 2,
          selfY: 0,
        ),
      );

      expect(decision.moveDir, Vector2.zero());
    });

    test('nan_observation_steer_vector_is_zero', () {
      const nan = double.nan;
      final decision = const HammerSteering().sample(
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );

      expect(decision.moveDir, Vector2.zero());
    });
  });

  group('steering sanitization', () {
    test('nan_race_observation_keeps_move_vector_finite', () {
      const nan = double.nan;
      final race = const RaceSteering().sample(
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );

      expect(
        race.moveDir.x,
        1,
        reason: 'race policy is pose-independent (constant right)',
      );
    });
  });
}
