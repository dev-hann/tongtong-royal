import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

void main() {
  group('RaceSteering', () {
    test('auto-runs right at full deflection, no auto jump', () {
      final decision = const RaceSteering().sample(
        const SteeringObservation(tick: 0, selfX: 0, selfY: 0),
      );
      expect(decision.moveDir.x, 1);
      expect(decision.moveDir.y, 0);
      expect(decision.jumpPressed, isFalse);
    });

    test('ignores pose noise (constant right regardless)', () {
      final decision = const RaceSteering().sample(
        const SteeringObservation(tick: 99, selfX: 40, selfY: -3, selfVy: 5),
      );
      expect(decision.moveDir.x, 1);
      expect(decision.moveDir.y, 0);
    });
  });

  group('HammerSteering', () {
    test('seeks center from beyond the right band edge', () {
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

    test('seeks center from beyond the left band edge', () {
      final decision = const HammerSteering().sample(
        const SteeringObservation(
          tick: 0,
          selfX: -HammerSteering.centerBandMeters - 1,
          selfY: 0,
        ),
      );
      expect(decision.moveDir.x, 1);
    });

    test('idles (zero drift) inside the center band', () {
      final decision = const HammerSteering().sample(
        const SteeringObservation(
          tick: 0,
          selfX: HammerSteering.centerBandMeters / 2,
          selfY: 0,
        ),
      );
      expect(decision.moveDir, Vector2.zero());
    });
  });

  group('steering sanitization', () {
    test('NaN observations: pose-dependent policies collapse to zero', () {
      const nan = double.nan;
      final hammer = const HammerSteering().sample(
        const SteeringObservation(tick: 0, selfX: nan, selfY: 0),
      );
      expect(hammer.moveDir, Vector2.zero());

      final race = const RaceSteering().sample(
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );
      expect(race.moveDir.x, 1,
          reason: 'race policy is pose-independent (constant right)');
    });
  });
}
