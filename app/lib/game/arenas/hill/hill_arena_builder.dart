import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/character_world.dart';

/// Builds a [HillArenaMap] into a live [CharacterWorld]: floor slab,
/// crown platform, ramp steps. Data in, bodies out — no rules.
///
/// Crown-zone occupancy is NOT sensed by a fixture here: the zone's
/// scoring radius is map data, and HillSimulation decides occupancy
/// with a position test (grounded + within radius + standing at top
/// height). A sensor fixture would misfire on floor-level players
/// whose heads graze the zone volume beside the platform.
abstract final class HillArenaBuilder {
  /// Builds [map] into [world].
  static void build(CharacterWorld world, HillArenaMap map) {
    world.addStaticBox(
      center: map.floor.center,
      width: map.floor.width,
      height: map.floor.height,
    );
    final platform = map.crownPlatform;
    world.addStaticBox(
      center: platform.center,
      width: platform.width,
      height: platform.height,
    );
    for (final ramp in map.ramps) {
      world.addStaticBox(
        center: ramp.center,
        width: ramp.width,
        height: ramp.height,
      );
    }
  }
}
