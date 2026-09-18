import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:vector_math/vector_math_64.dart';

void expectVec(Vector2 actual, double x, double y) {
  expect(actual.x, closeTo(x, 1e-9));
  expect(actual.y, closeTo(y, 1e-9));
}

void main() {
  group('clampLinearVelocity', () {
    test('zero vector passes through as zero', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(Vector2.zero()),
        0,
        0,
      );
    });

    test('velocity under the cap is returned unchanged', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(Vector2(3, -4)),
        3,
        -4,
      );
    });

    test('velocity exactly at the cap is returned unchanged', () {
      const cap = PhysicsConsts.maxLinearVelocity;
      expectVec(
        PhysicsGuards.clampLinearVelocity(Vector2(cap, 0)),
        cap,
        0,
      );
    });

    test('over-cap velocity is capped and direction preserved', () {
      const cap = PhysicsConsts.maxLinearVelocity;
      final result = PhysicsGuards.clampLinearVelocity(
        Vector2(cap * 2, 0),
      );
      expectVec(result, cap, 0);
      expect(result.length, closeTo(cap, 1e-9));
    });

    test('over-cap diagonal velocity keeps its direction', () {
      const cap = PhysicsConsts.maxLinearVelocity;
      final result = PhysicsGuards.clampLinearVelocity(
        Vector2(cap * 1.5, cap * 2),
      );
      expect(result.length, closeTo(cap, 1e-9));
      expect(result.x, greaterThan(0));
      expect(result.y, greaterThan(result.x));
    });

    test('negative over-cap velocity is capped', () {
      const cap = PhysicsConsts.maxLinearVelocity;
      expectVec(
        PhysicsGuards.clampLinearVelocity(Vector2(-cap * 2, 0)),
        -cap,
        0,
      );
    });

    test('NaN in x collapses to zero vector', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(
          Vector2(double.nan, 1),
        ),
        0,
        0,
      );
    });

    test('NaN in y collapses to zero vector', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(
          Vector2(1, double.nan),
        ),
        0,
        0,
      );
    });

    test('infinite x collapses to zero vector', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(
          Vector2(double.infinity, 1),
        ),
        0,
        0,
      );
    });

    test('infinite y collapses to zero vector', () {
      expectVec(
        PhysicsGuards.clampLinearVelocity(
          Vector2(1, double.negativeInfinity),
        ),
        0,
        0,
      );
    });

    test('input vector is never mutated', () {
      final input = Vector2(3, -4);
      PhysicsGuards.clampLinearVelocity(input);
      expectVec(input, 3, -4);
    });
  });

  group('isExplosive', () {
    test('normal position and velocity are not explosive', () {
      expect(
        PhysicsGuards.isExplosive(
          Vector2(10, -20),
          Vector2(5, 5),
        ),
        isFalse,
      );
    });

    test('zero position and velocity are not explosive', () {
      expect(
        PhysicsGuards.isExplosive(Vector2.zero(), Vector2.zero()),
        isFalse,
      );
    });

    test('NaN in position x is explosive', () {
      expect(
        PhysicsGuards.isExplosive(
          Vector2(double.nan, 0),
          Vector2.zero(),
        ),
        isTrue,
      );
    });

    test('NaN in velocity y is explosive', () {
      expect(
        PhysicsGuards.isExplosive(
          Vector2.zero(),
          Vector2(0, double.nan),
        ),
        isTrue,
      );
    });

    test('infinite position x is explosive', () {
      expect(
        PhysicsGuards.isExplosive(
          Vector2(double.infinity, 0),
          Vector2.zero(),
        ),
        isTrue,
      );
    });

    test('negative infinite velocity y is explosive', () {
      expect(
        PhysicsGuards.isExplosive(
          Vector2.zero(),
          Vector2(0, double.negativeInfinity),
        ),
        isTrue,
      );
    });

    test('position component beyond tolerance is explosive', () {
      const bound = PhysicsConsts.worldBoundsTolerance;
      expect(
        PhysicsGuards.isExplosive(
          Vector2(bound * 2, 0),
          Vector2.zero(),
        ),
        isTrue,
      );
    });

    test('negative velocity component beyond tolerance is explosive', () {
      const bound = PhysicsConsts.worldBoundsTolerance;
      expect(
        PhysicsGuards.isExplosive(
          Vector2.zero(),
          Vector2(0, -bound * 2),
        ),
        isTrue,
      );
    });

    test('position exactly at tolerance is not explosive', () {
      const bound = PhysicsConsts.worldBoundsTolerance;
      expect(
        PhysicsGuards.isExplosive(
          Vector2(bound, -bound),
          Vector2(bound, -bound),
        ),
        isFalse,
      );
    });
  });

  group('sanitizeJoystick', () {
    test('zero input stays zero', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2.zero()),
        0,
        0,
      );
    });

    test('valid input -1 passes through', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2(-1, 0.5)),
        -1,
        0.5,
      );
    });

    test('valid input 1 passes through', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2(0.25, 1)),
        0.25,
        1,
      );
    });

    test('1.5 is clamped down to 1', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2(1.5, 0)),
        1,
        0,
      );
    });

    test('-1.5 is clamped up to -1', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2(-1.5, 0)),
        -1,
        0,
      );
    });

    test('diagonal overshoot is clamped per component', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(Vector2(2, -2)),
        1,
        -1,
      );
    });

    test('NaN in any component collapses whole vector to zero', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(
          Vector2(double.nan, 0.5),
        ),
        0,
        0,
      );
    });

    test('infinity in any component collapses whole vector to zero', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(
          Vector2(0.5, double.negativeInfinity),
        ),
        0,
        0,
      );
    });

    test('all-NaN input collapses to zero', () {
      expectVec(
        PhysicsGuards.sanitizeJoystick(
          Vector2(double.nan, double.nan),
        ),
        0,
        0,
      );
    });

    test('input vector is never mutated', () {
      final input = Vector2(2, -2);
      PhysicsGuards.sanitizeJoystick(input);
      expectVec(input, 2, -2);
    });
  });
}
