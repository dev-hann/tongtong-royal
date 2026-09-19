import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('steering sanitization', () {
    test('NaN observations keep the move vector finite', () {
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
