import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('PlayerInputState', () {
    test('collapses NaN move direction to zero', () {
      final input = PlayerInputState(moveDir: Vector2(double.nan, 1));

      expect(input.moveDir, Vector2.zero());
    });

    test('clamps move direction components beyond 1', () {
      final input = PlayerInputState(moveDir: Vector2(2, -3));

      expect(input.moveDir, Vector2(1, -1));
    });

    test('keeps in-range move direction unchanged', () {
      final input = PlayerInputState(moveDir: Vector2(0.5, -0.25));

      expect(input.moveDir, Vector2(0.5, -0.25));
    });

    test('edges default to false', () {
      final input = PlayerInputState();

      expect(input.jumpPressed, isFalse);
      expect(input.dashPressed, isFalse);
    });
  });
}
