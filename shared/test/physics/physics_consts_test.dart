import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('PhysicsConsts', () {
    test('tick rate is positive', () {
      expect(PhysicsConsts.tickRate, greaterThan(0));
    });

    test('all double tuning constants are positive', () {
      const values = <double>[
        PhysicsConsts.fixedDt,
        PhysicsConsts.gravityMagnitude,
        PhysicsConsts.maxLinearVelocity,
        PhysicsConsts.maxAngularVelocity,
        PhysicsConsts.jumpImpulse,
        PhysicsConsts.dashImpulse,
        PhysicsConsts.moveForce,
        PhysicsConsts.moveMaxSpeed,
        PhysicsConsts.minWallThickness,
        PhysicsConsts.stuckThresholdSeconds,
        PhysicsConsts.playerGroundFriction,
        PhysicsConsts.playerPlayerFriction,
        PhysicsConsts.restitutionGround,
        PhysicsConsts.restitutionPlayer,
        PhysicsConsts.worldBoundsTolerance,
      ];
      for (final value in values) {
        expect(value, greaterThan(0));
      }
    });

    test('fixed dt is the exact inverse of tick rate', () {
      expect(
        PhysicsConsts.fixedDt * PhysicsConsts.tickRate,
        closeTo(1, 1e-9),
      );
    });

    test('contact parameters stay in physical [0, 1] range', () {
      const params = <double>[
        PhysicsConsts.playerGroundFriction,
        PhysicsConsts.playerPlayerFriction,
        PhysicsConsts.restitutionGround,
        PhysicsConsts.restitutionPlayer,
      ];
      for (final param in params) {
        expect(param, inInclusiveRange(0, 1));
      }
    });

    test('wall thickness is meaningful for a 1.5 m tall player', () {
      expect(
        PhysicsConsts.minWallThickness,
        inInclusiveRange(0.05, 0.5),
      );
    });
  });

  group('PhysicsConsts network cadence', () {
    test('snapshot rate is 20 Hz (network doc § 1)', () {
      expect(PhysicsConsts.snapshotRateHz, 20);
    });

    test('snapshot rate is positive', () {
      expect(PhysicsConsts.snapshotRateHz, greaterThan(0));
    });

    test('tick rate is an exact multiple of the snapshot rate', () {
      expect(PhysicsConsts.tickRate % PhysicsConsts.snapshotRateHz, 0);
    });

    test('progress samples land every 10 ticks (GDD § 7.4)', () {
      expect(PhysicsConsts.progressSampleIntervalTicks, 10);
    });

    test('progress sample interval is positive', () {
      expect(PhysicsConsts.progressSampleIntervalTicks, greaterThan(0));
    });
  });
}
