import 'package:app/game/arenas/hill/hill_arena_map.dart';
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

  group('HillSteering', () {
    final map = HillArenaMap.kingOfTheHill(1);
    late HillSteering steering;

    setUp(() {
      steering = HillSteering.fromArenaMap(map);
    });

    double rampMinX(int index) =>
        map.ramps[index].center.x - map.ramps[index].width / 2;

    test('walks toward the crown center from the left floor', () {
      final decision = steering.sample(
        const SteeringObservation(tick: 0, selfX: -6, selfY: 0.8),
      );
      expect(decision.moveDir.x, greaterThan(0));
      expect(decision.moveDir.y, 0);
    });

    test('walks toward the crown center from the right floor', () {
      final decision = steering.sample(
        const SteeringObservation(tick: 0, selfX: 6, selfY: 0.8),
      );
      expect(decision.moveDir.x, lessThan(0));
    });

    test('auto-jumps once at a step edge within look-ahead', () {
      final edgeX = rampMinX(3) - 0.5;
      final first = steering.sample(
        SteeringObservation(tick: 0, selfX: edgeX, selfY: 0.8),
      );
      expect(first.jumpPressed, isTrue,
          reason: 'outer-left ramp face is ahead within look-ahead');

      final second = steering.sample(
        SteeringObservation(tick: 1, selfX: edgeX, selfY: 0.8),
      );
      expect(second.jumpPressed, isFalse,
          reason: 'jump edge fires once, cooldown suppresses re-fire');
    });

    test('auto-jump recovers after the cooldown elapses', () {
      final edgeX = rampMinX(3) - 0.5;
      steering.sample(
        SteeringObservation(tick: 0, selfX: edgeX, selfY: 0.8),
      );
      final later = steering.sample(
        SteeringObservation(
          tick: HillSteering.jumpCooldownTicks + 1,
          selfX: edgeX,
          selfY: 0.8,
        ),
      );
      expect(later.jumpPressed, isTrue);
    });

    test('no auto-jump when no step edge is within look-ahead', () {
      final farX = rampMinX(3) - HillSteering.lookAheadMeters - 1;
      final decision = steering.sample(
        SteeringObservation(tick: 0, selfX: farX, selfY: 0.8),
      );
      expect(decision.jumpPressed, isFalse);
    });

    test('no auto-jump while already up at the crown top', () {
      final onCrownY = map.crownTopY + 0.8;
      final decision = steering.sample(
        SteeringObservation(
          tick: 0,
          selfX: rampMinX(3) - 0.5,
          selfY: onCrownY,
        ),
      );
      expect(decision.jumpPressed, isFalse);
    });

    test('on crown, alone: holds inside the band, dash aims at center',
        () {
      final y = map.crownTopY + 0.8;
      final alone = steering.sample(
        SteeringObservation(tick: 0, selfX: map.crownCenter.x, selfY: y),
      );
      expect(alone.moveDir, Vector2.zero(),
          reason: 'sole occupant inside hold band stops fidgeting');
      expect(alone.jumpPressed, isFalse);

      final offCenter = steering.sample(
        SteeringObservation(
          tick: 1,
          selfX: map.crownCenter.x - 0.8,
          selfY: y,
        ),
      );
      expect(offCenter.moveDir.x, greaterThan(0));
      expect(offCenter.dashDir!.x, greaterThan(0),
          reason: 'no occupant: dash target is the crown center');
    });

    test('on crown: nearest occupant within shove range is dash target',
        () {
      final y = map.crownTopY + 0.8;
      final selfX = map.crownCenter.x + 0.6;
      final decision = steering.sample(
        SteeringObservation(
          tick: 0,
          selfX: selfX,
          selfY: y,
          nearbyPlayers: [
            (x: map.crownCenter.x - 0.9, y: y),
            (x: map.crownCenter.x + 1.7, y: y),
          ],
        ),
      );
      expect(decision.dashDir!.x, greaterThan(0),
          reason: 'nearest occupant sits to the right, center is left');
    });

    test('on crown: occupant beyond shove range falls back to center', () {
      final y = map.crownTopY + 0.8;
      final decision = steering.sample(
        SteeringObservation(
          tick: 0,
          selfX: map.crownCenter.x + 0.6,
          selfY: y,
          nearbyPlayers: [
            (x: map.crownCenter.x - 2.5, y: y),
          ],
        ),
      );
      expect(decision.dashDir!.x, lessThan(0),
          reason: 'occupant out of reach: dash toward crown center');
    });

    test('off-crown players are not dash targets while climbing', () {
      final decision = steering.sample(
        const SteeringObservation(
          tick: 0,
          selfX: -6,
          selfY: 0.8,
          nearbyPlayers: [(x: -6.5, y: 0.8)],
        ),
      );
      expect(decision.dashDir, isNull);
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

    test('hill NaN observation collapses to zero, no jump, no crash', () {
      final map = HillArenaMap.kingOfTheHill(1);
      const nan = double.nan;
      final decision = HillSteering.fromArenaMap(map).sample(
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );
      expect(decision.moveDir, Vector2.zero());
      expect(decision.jumpPressed, isFalse);
    });
  });
}
