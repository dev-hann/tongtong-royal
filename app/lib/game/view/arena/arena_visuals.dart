import 'dart:ui' show Canvas;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/view/arena/arena_camera.dart';
import 'package:app/game/view/arena/hammer_arena_painter.dart';
import 'package:app/game/view/arena/hill_arena_painter.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Per-arena render data: camera bounds, static-geometry drawing and
/// arm-angle kinematics, all from map data only (Forge2D bodies are
/// never touched). Sealed union of the two arena archetypes.
sealed class ArenaVisuals {
  const ArenaVisuals();

  /// Camera clamp rectangle.
  ArenaCameraBounds get bounds;

  /// Hammer arm specs of this arena (empty for hill).
  List<HammerSpec> get hammers => const [];

  /// Draws the arena in world coordinates (call under the view's
  /// meter/y-flip transform) after [ticks] simulation steps.
  void draw(Canvas canvas, int ticks);
}

/// Render angle of hammer arm [spec] after [ticks] steps, radians.
/// Parity with the physics: arms are kinematic bodies rotating at
/// constant [HammerSpec.angularSpeed] from
/// [HammerSpec.initialAngle] (hammer_builder sets exactly that angle
/// and angular velocity), so the angle is initial + speed * ticks *
/// fixed dt — the same constant-velocity approximation the survival
/// bot's hazard extrapolation uses.
double hammerArmAngle(HammerSpec spec, int ticks) =>
    spec.initialAngle + spec.angularSpeed * ticks * PhysicsConsts.fixedDt;

/// Render data for a Hammer Dodge arena.
final class HammerArenaVisuals extends ArenaVisuals {
  /// Creates hammer-arena visuals over [map].
  const HammerArenaVisuals(this.map);

  /// Arena map data rendered by these visuals.
  final HammerArenaMap map;

  @override
  ArenaCameraBounds get bounds => ArenaCameraBounds.fromHammerMap(map);

  @override
  List<HammerSpec> get hammers => map.hammers;

  @override
  void draw(Canvas canvas, int ticks) => drawHammerArena(
    map: map,
    canvas: canvas,
    armAngles: [for (final spec in map.hammers) hammerArmAngle(spec, ticks)],
  );
}

/// Render data for a King of the Hill arena.
final class HillArenaVisuals extends ArenaVisuals {
  /// Creates hill-arena visuals over [map].
  const HillArenaVisuals(this.map);

  /// Arena map data rendered by these visuals.
  final HillArenaMap map;

  @override
  ArenaCameraBounds get bounds => ArenaCameraBounds.fromHillMap(map);

  @override
  void draw(Canvas canvas, int ticks) =>
      drawHillArena(map: map, canvas: canvas);
}
