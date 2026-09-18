import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Renderable pose of one player at the sampled render time.
@immutable
final class PlayerRenderPose {
  /// Creates a pose; world meters / radians.
  const PlayerRenderPose({
    required this.x,
    required this.y,
    required this.angle,
  });

  /// Position X in meters.
  final double x;

  /// Position Y in meters.
  final double y;

  /// Body rotation in radians.
  final double angle;
}

/// Everything a renderer needs for one frame: the local player id,
/// the world tick the state corresponds to (drives kinematic
/// animation such as hammer angles) and one pose per known player.
@immutable
final class RemoteRenderState {
  /// Creates the state.
  const RemoteRenderState({
    required this.localPlayerId,
    required this.worldTick,
    required this.players,
  });

  /// Player the camera follows.
  final PlayerId localPlayerId;

  /// World tick this state represents (fractional origins are fine;
  /// consumers treat it as elapsed simulation time).
  final int worldTick;

  /// Poses to draw, keyed by player id.
  final Map<PlayerId, PlayerRenderPose> players;
}

/// Source of per-frame render state for the game view.
///
/// The view owns no simulation of its own for remote players
/// (architecture doc § 9); it samples this feed once per frame.
/// Course statics (platforms, walls, hammers) are NOT part of the
/// sampled state — both sides build identical statics from
/// `minigameId + mapSeed` (network doc § 4) — so the feed exposes
/// the [map] once instead of per frame.
// Single-method seam: the injectable render-state boundary required
// by the view, not an accidental class.
// ignore: one_member_abstracts
abstract interface class RenderFeed {
  /// Player the camera follows.
  PlayerId get localPlayerId;

  /// Static course data (identical on host and clients by seed).
  CourseMap get map;

  /// State to draw this frame.
  RemoteRenderState sample();
}

/// [RenderFeed] over a live [RaceSimulation] — the local path
/// (single-player and host). Read-only: stepping stays with the
/// simulation's owner; this feed only samples body transforms.
final class LocalRenderFeed implements RenderFeed {
  /// Creates a feed reading [simulation].
  LocalRenderFeed({
    required this.simulation,
    required this.map,
    required this.localPlayerId,
    this.playerIds = const [],
  });

  /// Simulation whose bodies are sampled.
  final RaceSimulation simulation;

  @override
  final CourseMap map;

  @override
  final PlayerId localPlayerId;

  /// Players to report; empty reports only [localPlayerId].
  final List<PlayerId> playerIds;

  @override
  RemoteRenderState sample() {
    final ids = playerIds.isEmpty ? [localPlayerId] : playerIds;
    final players = <PlayerId, PlayerRenderPose>{};
    for (final id in ids) {
      final body = simulation.bodyOf(id);
      players[id] = PlayerRenderPose(
        x: body.position.x,
        y: body.position.y,
        angle: body.angle,
      );
    }
    return RemoteRenderState(
      localPlayerId: localPlayerId,
      worldTick: simulation.currentTick,
      players: players,
    );
  }
}
