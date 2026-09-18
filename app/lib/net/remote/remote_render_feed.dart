import 'dart:async';

import 'package:app/game/course/course_map.dart';
import 'package:app/game/view/race_game_view.dart' show InputSource;
import 'package:app/net/remote/local_prediction.dart';
import 'package:app/net/remote/render_feed.dart';
import 'package:app/net/remote/snapshot_buffer.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Clock used by the remote feed: elapsed time since an arbitrary
/// epoch. Injectable so tests never depend on wall time (same shape
/// as `infra`'s `NetClock`, kept local to avoid a view-level
/// dependency on the network stack's internals).
typedef RemoteClock = Duration Function();

/// Upper bound on the prediction dt per sample. A paused tab or a
/// slow frame must not teleport the local prediction meters ahead;
/// anything past this window is discarded (the next snapshot
/// reconciles anyway).
const double maxPredictionFrameDtSeconds = 0.25;

/// [RenderFeed] for a remote (non-host) client: consumes
/// `NetClient.gameSnapshots`, interpolates every remote player
/// between the two most recent buffered snapshots (network doc § 1)
/// and renders the local player from [LocalPrediction] only
/// (architecture doc § 9 — remote players are never simulated
/// client-side).
///
/// Starvation (fewer than two snapshots, or arrival gaps beyond
/// [maxInterpolationGap]) holds the last state; the local prediction
/// keeps integrating input from its last authoritative state.
final class RemoteRenderFeed implements RenderFeed {
  /// Creates the feed over [snapshots] (typically
  /// `NetClient.gameSnapshots`; already tick-filtered, this buffer
  /// re-checks defensively).
  RemoteRenderFeed({
    required Stream<Snapshot> snapshots,
    required this.localPlayerId,
    required this.map,
    required RemoteClock clock,
    InputSource? inputSource,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _inputSource = inputSource, // ignore: prefer_initializing_formals
       _prediction = LocalPrediction(playerId: localPlayerId) {
    _subscription = snapshots.listen(_onSnapshot);
  }

  @override
  final PlayerId localPlayerId;

  @override
  final CourseMap map;

  final RemoteClock _clock;
  final InputSource? _inputSource;
  final SnapshotBuffer _buffer = SnapshotBuffer();
  final LocalPrediction _prediction;

  StreamSubscription<Snapshot>? _subscription;
  Duration? _lastSampleAt;
  bool _disposed = false;

  void _onSnapshot(Snapshot snapshot) {
    if (_disposed) {
      return;
    }
    _buffer.push(snapshot, arrivalTime: _clock());
    for (final player in snapshot.players) {
      if (player.playerId == localPlayerId) {
        _prediction.applySnapshot(player);
        break;
      }
    }
  }

  @override
  RemoteRenderState sample() {
    final now = _clock();
    var dtSeconds = 0.0;
    final lastSampleAt = _lastSampleAt;
    if (lastSampleAt != null) {
      dtSeconds = (now - lastSampleAt).inMicroseconds / 1e6;
      if (dtSeconds > maxPredictionFrameDtSeconds) {
        dtSeconds = maxPredictionFrameDtSeconds;
      }
    }
    _lastSampleAt = now;

    final players = <PlayerId, PlayerRenderPose>{};
    var worldTick = 0;
    final interpolated = _buffer.sample(now: now);
    if (interpolated != null) {
      players.addAll(interpolated.players);
      worldTick = interpolated.tick.round();
    }

    // Local player: prediction (architecture doc § 9), not
    // interpolation — authoritative state plus live input.
    _prediction.integrate(
      input: _inputSource?.sample() ?? PlayerInputState(),
      dtSeconds: dtSeconds,
    );
    if (_prediction.hasState) {
      players[localPlayerId] = _prediction.predictedPose;
    }

    return RemoteRenderState(
      localPlayerId: localPlayerId,
      worldTick: worldTick,
      players: players,
    );
  }

  /// Stops consuming snapshots. Call when the feed leaves the tree.
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
  }
}
