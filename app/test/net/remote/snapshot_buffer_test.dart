import 'dart:math' as math;

import 'package:app/net/remote/snapshot_buffer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

PlayerState _state(String id, {double x = 0, double angle = 0}) =>
    PlayerState(playerId: id, x: x, y: 0, angle: angle, vx: 0, vy: 0);

Snapshot _snapTick(int tick) => Snapshot(tick: tick, players: [_state('p1')]);

extension _PushForTest on SnapshotBuffer {
  /// Pushes 'p1' as [tick] arriving at [arrivalMs]; optional [x] /
  /// [angle] / [extra] player (`(id, x)`).
  void _pushForTest(
    int tick,
    int arrivalMs, {
    double x = 0,
    double angle = 0,
    (String, double)? extra,
  }) {
    push(
      Snapshot(
        tick: tick,
        players: [
          _state('p1', x: x, angle: angle),
          if (extra != null) _state(extra.$1, x: extra.$2),
        ],
      ),
      arrivalTime: Duration(milliseconds: arrivalMs),
    );
  }
}

void main() {
  group('push ordering (network doc § 1: later tick wins)', () {
    test('accepts monotonically increasing ticks', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100)
        .._pushForTest(2, 150);
      expect(buffer.sample(now: const Duration(milliseconds: 300)), isNotNull);
    });

    test('drops out-of-order and duplicate ticks', () {
      final buffer = SnapshotBuffer().._pushForTest(3, 100);
      expect(
        buffer.push(
          _snapTick(2),
          arrivalTime: const Duration(milliseconds: 150),
        ),
        isFalse,
      );
      expect(
        buffer.push(
          _snapTick(3),
          arrivalTime: const Duration(milliseconds: 160),
        ),
        isFalse,
      );
      final sample = buffer.sample(now: const Duration(milliseconds: 300))!;
      expect(sample.players['p1']!.x, 0);
      // The accepted next tick still works after the drops.
      expect(
        buffer.push(
          Snapshot(tick: 4, players: [_state('p1', x: 7)]),
          arrivalTime: const Duration(milliseconds: 200),
        ),
        isTrue,
      );
    });

    test('empty buffer samples to null', () {
      final buffer = SnapshotBuffer();
      expect(buffer.sample(now: Duration.zero), isNull);
    });
  });

  group('sample interpolation (network doc § 1: render at T-2)', () {
    test('fewer than two snapshots holds the single snapshot', () {
      final buffer = SnapshotBuffer().._pushForTest(1, 100, x: 5);
      final sample = buffer.sample(now: const Duration(milliseconds: 150));
      expect(sample, isNotNull);
      expect(sample!.players['p1']!.x, 5);
      expect(sample.tick, 1);
    });

    test('render time between two snapshots lerps exactly (midpoint)', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100)
        .._pushForTest(2, 200, x: 10);
      // Render clock = now - 100 ms → midway between arrivals.
      final sample = buffer.sample(now: const Duration(milliseconds: 250));
      expect(sample!.players['p1']!.x, moreOrLessEquals(5, epsilon: 1e-9));
      expect(sample.tick, moreOrLessEquals(1.5, epsilon: 1e-9));
    });

    test('quarter-point interpolation is exact', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(10, 100)
        .._pushForTest(12, 200, x: 8);
      // renderTime = 125 ms → t = 0.25 → x = 2, tick = 10.5.
      final sample = buffer.sample(now: const Duration(milliseconds: 225));
      expect(sample!.players['p1']!.x, moreOrLessEquals(2, epsilon: 1e-9));
      expect(sample.tick, moreOrLessEquals(10.5, epsilon: 1e-9));
    });

    test('render time beyond newest holds it (no extrapolation)', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100)
        .._pushForTest(2, 200, x: 10);
      final sample = buffer.sample(now: const Duration(seconds: 5));
      expect(sample!.players['p1']!.x, 10);
      expect(sample.tick, 2);
    });

    test('angle lerps along the shortest arc', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100, angle: 3)
        .._pushForTest(2, 200, angle: -3);
      // Shortest arc from 3.0 to -3.0 crosses pi, not zero.
      final sample = buffer.sample(now: const Duration(milliseconds: 250));
      expect(
        sample!.players['p1']!.angle,
        moreOrLessEquals(math.pi, epsilon: 1e-6),
      );
    });

    test('player present in only one snapshot keeps that pose', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100)
        .._pushForTest(2, 200, x: 10, extra: ('p2', 4));
      final sample = buffer.sample(now: const Duration(milliseconds: 250));
      expect(sample!.players['p2']!.x, 4);
    });
  });

  group('starvation (network doc § 6: hold last state)', () {
    test(
      'gap over 2 s between straddling snapshots holds the pre-gap pose',
      () {
        final buffer = SnapshotBuffer()
          .._pushForTest(1, 100)
          .._pushForTest(2, 3000, x: 100);
        // renderTime = 1500 ms falls inside the 2.9 s gap → hold pre-gap.
        final sample = buffer.sample(now: const Duration(milliseconds: 1600));
        expect(sample!.players['p1']!.x, 0);
        expect(sample.tick, 1);
      },
    );

    test('gap under 2 s still interpolates', () {
      final buffer = SnapshotBuffer()
        .._pushForTest(1, 100)
        .._pushForTest(2, 1000, x: 10);
      // renderTime = 550 ms → t = 0.5 → x = 5, tick = 1.5.
      final sample = buffer.sample(now: const Duration(milliseconds: 650));
      expect(sample!.players['p1']!.x, moreOrLessEquals(5, epsilon: 1e-9));
      expect(sample.tick, moreOrLessEquals(1.5, epsilon: 1e-9));
    });
  });
}
