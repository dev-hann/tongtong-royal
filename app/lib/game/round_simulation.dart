import 'dart:async';

import 'package:tongtong_shared/tongtong_shared.dart';

/// Snapshot-ready pose of one player body: position, rotation and
/// linear velocity, all read atomically after a tick.
typedef PlayerPose = ({double x, double y, double angle, double vx, double vy});

/// Common round-simulation seam across minigame archetypes
/// (architecture doc § 2: the host simulates, the domain judges).
///
/// The host runtime drives whichever course simulation the round's
/// minigame maps to through this interface alone; archetype
/// specifics stay behind it.
abstract interface class RoundSimulation {
  /// Raw round events in emission order (synchronous broadcast).
  Stream<RoundEvent> get events;

  /// Whether the simulation itself considers the round over (all
  /// finished, last standing, internal timeout). The host may still
  /// end the round earlier on its own timeout.
  bool get isComplete;

  /// X anchor for forward-progress sampling (race archetype), or
  /// null when the archetype has no course anchor (arenas).
  double? get progressAnchorX;

  /// Snapshot pose of [playerId], or null when the player has no
  /// body (eliminated — survival archetype).
  PlayerPose? poseOf(PlayerId playerId);

  /// Applies one input per player and advances the world a single
  /// fixed dt — the host's batched per-tick entry point.
  void tickInputs(Map<PlayerId, PlayerInputState> inputs);

  /// Releases the event stream.
  void dispose();
}
