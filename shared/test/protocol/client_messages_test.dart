import 'package:test/test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('PlayerInputMessage defensive constructor', () {
    test('keeps in-range values', () {
      final msg = PlayerInputMessage(
        seq: 7,
        moveX: -0.5,
        moveY: 0.25,
        jump: true,
        dash: false,
      );
      expect(msg.moveX, -0.5);
      expect(msg.moveY, 0.25);
    });

    test('clamps moveX above 1', () {
      final msg = PlayerInputMessage(
        seq: 1,
        moveX: 1.7,
        moveY: 0,
        jump: false,
        dash: false,
      );
      expect(msg.moveX, 1.0);
    });

    test('clamps moveY below -1', () {
      final msg = PlayerInputMessage(
        seq: 1,
        moveX: 0,
        moveY: -3.2,
        jump: false,
        dash: false,
      );
      expect(msg.moveY, -1.0);
    });

    test('NaN collapses to 0', () {
      final msg = PlayerInputMessage(
        seq: 1,
        moveX: double.nan,
        moveY: double.nan,
        jump: false,
        dash: false,
      );
      expect(msg.moveX, 0.0);
      expect(msg.moveY, 0.0);
    });

    test('infinity clamps to sign', () {
      final msg = PlayerInputMessage(
        seq: 1,
        moveX: double.infinity,
        moveY: double.negativeInfinity,
        jump: false,
        dash: false,
      );
      expect(msg.moveX, 1.0);
      expect(msg.moveY, -1.0);
    });
  });
}
