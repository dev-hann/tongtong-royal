import 'dart:math' as math;

import 'package:app/net/remote/render_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Interpolation delay: the renderer draws at "now minus 100 ms"
/// (network doc § 1: render at tick T-2 while buffering T and T-1 at
/// the 20 Hz snapshot rate). Engine/netcode constant from the network
/// doc, not gameplay tuning.
const Duration interpolationDelay = Duration(milliseconds: 100);

/// Maximum arrival-time gap the buffer will interpolate across; a
/// wider gap means the feed is starved and the last state is held
/// instead (network doc § 6: no snapshot for 2 s → freeze
/// interpolation, never extrapolate).
const Duration maxInterpolationGap = Duration(seconds: 2);

/// Upper bound on buffered snapshots (~3 s at the 20 Hz broadcast
/// rate). Memory guard only; older entries can never be needed again
/// because render time trails the newest arrival by 100 ms.
const int maxBufferedSnapshots = 64;

/// One accepted snapshot with the (injected) clock reading of its
/// arrival. Arrival time, not host tick, is the interpolation domain:
/// client clocks only measure their own timeline (network doc § 9,
/// "server timestamps arrival; host tick numbers order the world" —
/// here the local arrival clock orders the local buffer).
@immutable
final class _BufferedSnapshot {
  const _BufferedSnapshot(this.snapshot, this.arrivalTime);

  final Snapshot snapshot;
  final Duration arrivalTime;
}

/// Pure snapshot interpolator for a remote client: snapshots are
/// pushed with an injected arrival time and sampled at an injected
/// "now", so the class has no clock dependency and is fully
/// deterministic in tests.
///
/// Mapping (documented per task): each pushed snapshot records the
/// caller-supplied arrival time. Render time is `now -
/// [interpolationDelay]`. The two entries whose arrival times
/// straddle render time are lerped (positions linearly, angles along
/// the shortest arc, tick linearly).
///
/// Hold rules (never extrapolate):
/// - no snapshots → `null`;
/// - fewer than two snapshots → hold the single snapshot;
/// - render time before the oldest arrival → hold the oldest;
/// - render time after the newest arrival → hold the newest;
/// - a straddling pair farther apart than [maxInterpolationGap] →
///   hold the pre-gap (older) entry.
final class SnapshotBuffer {
  final List<_BufferedSnapshot> _entries = [];
  int? _newestTick;

  /// Inserts [snapshot] arriving at [arrivalTime]. Later tick wins:
  /// a snapshot with tick ≤ the newest buffered tick is dropped
  /// (network doc § 1). Returns whether it was accepted.
  bool push(Snapshot snapshot, {required Duration arrivalTime}) {
    final newestTick = _newestTick;
    if (newestTick != null && snapshot.tick <= newestTick) {
      return false;
    }
    _newestTick = snapshot.tick;
    _entries.add(_BufferedSnapshot(snapshot, arrivalTime));
    if (_entries.length > maxBufferedSnapshots) {
      _entries.removeRange(0, _entries.length - maxBufferedSnapshots);
    }
    return true;
  }

  /// Interpolated world state to draw at `now`, or `null` when no
  /// snapshot has ever been pushed. See the class doc for the hold
  /// rules.
  InterpolatedSnapshot? sample({required Duration now}) {
    if (_entries.isEmpty) {
      return null;
    }
    if (_entries.length == 1) {
      return _hold(_entries.single);
    }
    final renderTime = now - interpolationDelay;
    if (renderTime >= _entries.last.arrivalTime) {
      return _hold(_entries.last);
    }
    if (renderTime <= _entries.first.arrivalTime) {
      return _hold(_entries.first);
    }
    for (var i = 0; i < _entries.length - 1; i++) {
      final older = _entries[i];
      final newer = _entries[i + 1];
      if (renderTime >= older.arrivalTime && renderTime <= newer.arrivalTime) {
        if (newer.arrivalTime - older.arrivalTime > maxInterpolationGap) {
          // Starved feed: freeze at the pre-gap state (network doc § 6).
          return _hold(older);
        }
        return _interpolate(older, newer, renderTime);
      }
    }
    // Unreachable given the boundary checks above; hold newest.
    return _hold(_entries.last);
  }

  static InterpolatedSnapshot _hold(_BufferedSnapshot entry) {
    return InterpolatedSnapshot(
      tick: entry.snapshot.tick.toDouble(),
      players: {
        for (final player in entry.snapshot.players)
          player.playerId: PlayerRenderPose(
            x: player.x,
            y: player.y,
            angle: player.angle,
          ),
      },
    );
  }

  static InterpolatedSnapshot _interpolate(
    _BufferedSnapshot older,
    _BufferedSnapshot newer,
    Duration renderTime,
  ) {
    final span = (newer.arrivalTime - older.arrivalTime).inMicroseconds
        .toDouble();
    final t = (renderTime - older.arrivalTime).inMicroseconds.toDouble() / span;

    final players = <PlayerId, PlayerRenderPose>{
      for (final player in older.snapshot.players)
        player.playerId: PlayerRenderPose(
          x: player.x,
          y: player.y,
          angle: player.angle,
        ),
    };
    for (final player in newer.snapshot.players) {
      final previous = players[player.playerId];
      if (previous == null) {
        // Player absent from the older snapshot: keep the newer pose.
        players[player.playerId] = PlayerRenderPose(
          x: player.x,
          y: player.y,
          angle: player.angle,
        );
        continue;
      }
      players[player.playerId] = PlayerRenderPose(
        x: _lerp(previous.x, player.x, t),
        y: _lerp(previous.y, player.y, t),
        angle: previous.angle + _shortestArc(previous.angle, player.angle) * t,
      );
    }
    return InterpolatedSnapshot(
      tick: _lerp(
        older.snapshot.tick.toDouble(),
        newer.snapshot.tick.toDouble(),
        t,
      ),
      players: players,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Signed shortest rotation from [from] to [to], in (-π, π].
  static double _shortestArc(double from, double to) {
    const twoPi = 2 * math.pi;
    var delta = (to - from) % twoPi;
    if (delta > math.pi) {
      delta -= twoPi;
    } else if (delta < -math.pi) {
      delta += twoPi;
    }
    return delta;
  }
}

/// Result of [SnapshotBuffer.sample]: a world tick (fractional when
/// interpolated) plus one pose per known player.
@immutable
final class InterpolatedSnapshot {
  /// Creates the sampled state.
  const InterpolatedSnapshot({required this.tick, required this.players});

  /// World tick the sampled state corresponds to.
  final double tick;

  /// Player poses at the sampled render time.
  final Map<PlayerId, PlayerRenderPose> players;
}
