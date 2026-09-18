import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('PlayerInputState', () {
    test('sanitizes move direction beyond the unit square', () {
      final input = PlayerInputState(moveDir: Vector2(2, -3));

      expect(input.moveDir, Vector2(1, -1));
    });

    test('collapses non-finite move direction to zero', () {
      final input = PlayerInputState(moveDir: Vector2(double.nan, 1));

      expect(input.moveDir, Vector2.zero());
    });

    test('keeps in-range move direction unchanged', () {
      final input = PlayerInputState(moveDir: Vector2(0.5, -0.25));

      expect(input.moveDir, Vector2(0.5, -0.25));
    });

    test('stores jump and dash edges', () {
      final input = PlayerInputState(jumpPressed: true, dashPressed: true);

      expect(input.jumpPressed, isTrue);
      expect(input.dashPressed, isTrue);
    });

    test('edges default to false', () {
      final input = PlayerInputState();

      expect(input.jumpPressed, isFalse);
      expect(input.dashPressed, isFalse);
    });
  });
}
