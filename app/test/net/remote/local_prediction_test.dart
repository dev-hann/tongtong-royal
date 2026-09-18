import 'package:app/net/remote/local_prediction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

PlayerState _state({
  double x = 0,
  double y = 0,
  double vx = 0,
  double vy = 0,
  double angle = 0,
}) => PlayerState(playerId: 'me', x: x, y: y, angle: angle, vx: vx, vy: vy);

void main() {
  group('seeding', () {
    test('first snapshot is adopted verbatim', () {
      final prediction = LocalPrediction(playerId: 'me');
      expect(prediction.hasState, isFalse);
      prediction.applySnapshot(_state(x: 3, y: 2, angle: 0.5));
      expect(prediction.hasState, isTrue);
      expect(prediction.predictedPose.x, 3);
      expect(prediction.predictedPose.y, 2);
      expect(prediction.predictedPose.angle, 0.5);
    });

    test('predict without any snapshot reports no state', () {
      final prediction = LocalPrediction(playerId: 'me')
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 1,
        );
      expect(prediction.hasState, isFalse);
    });
  });

  group('dead reckoning between snapshots', () {
    test('integrates velocity plus input direction at moveMaxSpeed', () {
      // No new snapshot: input right (1,0) for 0.5 s twice:
      // x += (vx 1 + 6) * 0.5 per call → 3.5 m per half second.
      final prediction = LocalPrediction(playerId: 'me')
        ..applySnapshot(_state(vx: 1))
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 0.5,
        )
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 0.5,
        );
      expect(prediction.predictedPose.x, moreOrLessEquals(7, epsilon: 1e-9));
      expect(prediction.predictedPose.y, 0);
    });
  });

  group('reconciliation', () {
    test('near authoritative state blends toward it without reaching it', () {
      // Predicted x = 6 after seeding and 1 s of right input;
      // authoritative x = 6.3 → distance 0.3 ≤ 0.5.
      final prediction = LocalPrediction(playerId: 'me')
        ..applySnapshot(_state())
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 1,
        )
        // Blend: 6 + 0.1 * 0.3 = 6.03 — moved toward, not equal.
        ..applySnapshot(_state(x: 6.3));
      expect(prediction.predictedPose.x, moreOrLessEquals(6.03, epsilon: 1e-9));
    });

    test('far authoritative state snaps exactly', () {
      // Predicted x = 6; authoritative x = 10 → distance 4 > 0.5 → snap.
      final prediction = LocalPrediction(playerId: 'me')
        ..applySnapshot(_state())
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 1,
        )
        ..applySnapshot(_state(x: 10, y: -2, angle: 1));
      expect(prediction.predictedPose.x, 10);
      expect(prediction.predictedPose.y, -2);
      expect(prediction.predictedPose.angle, 1);
    });

    test('authoritative velocity replaces the predicted one', () {
      final prediction = LocalPrediction(playerId: 'me')
        ..applySnapshot(_state())
        ..integrate(
          input: PlayerInputState(moveDir: Vector2(1, 0)),
          dtSeconds: 1,
        )
        ..applySnapshot(_state(x: 6.1, vx: 2))
        // Idle input: x = 6.01 (blend) + vx 2 * 1 s.
        ..integrate(input: PlayerInputState(), dtSeconds: 1);
      expect(prediction.predictedPose.x, moreOrLessEquals(8.01, epsilon: 1e-9));
    });
  });
}
