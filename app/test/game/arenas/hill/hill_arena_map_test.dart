import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HillArenaMap', () {
    test('blueprint_has_floor_four_ramps_four_spawns_and_crown', () {
      final map = HillArenaMap.kingOfTheHill(7);

      expect(map.spawnPoints, hasLength(4));
      expect(map.ramps, hasLength(4));
      // All spawns sit just above the floor surface.
      const anchor = PlayerCharacter.heightMeters / 2 + 0.01;
      for (final spawn in map.spawnPoints) {
        expect(spawn.y, closeTo(anchor, 1e-9));
        // Spawn x stays inside the floor and outside the crown zone.
        expect(spawn.x.abs(), lessThan(map.floor.width / 2));
      }
      // Crown sits on the floor surface, elevated by its height.
      final floorSurface = map.floor.center.y + map.floor.height / 2;
      expect(map.crownTopY, closeTo(floorSurface + map.crownHeight, 1e-9));
      expect(map.crownHeight, greaterThan(0));
      expect(map.crownRadius, greaterThan(0));
      // Kill line lies below the floor slab.
      expect(map.killY, lessThan(map.floor.center.y - map.floor.height / 2));
    });

    test('seed_jitters_crown_center_within_bounds', () {
      for (final seed in [0, 1, 2, 3, 42]) {
        final map = HillArenaMap.kingOfTheHill(seed);
        expect(map.crownCenter.x.abs(), lessThan(0.5 + 1e-9));
        expect(map.crownCenter.x, isNot(0),
            reason: 'seed $seed jittered to exactly 0');
      }
    });

    test('same_seed_same_map', () {
      expect(HillArenaMap.kingOfTheHill(7), HillArenaMap.kingOfTheHill(7));
    });

    test('different_seeds_produce_different_crown_centers', () {
      final a = HillArenaMap.kingOfTheHill(1);
      final b = HillArenaMap.kingOfTheHill(2);
      expect(a.crownCenter.x, isNot(b.crownCenter.x));
    });

    test('json_roundtrip_is_equal', () {
      final map = HillArenaMap.kingOfTheHill(9);
      expect(HillArenaMap.fromJson(map.toJson()), map);
    });

    test('malformed_json_throws_format_exception', () {
      expect(() => HillArenaMap.fromJson(const {}), throwsFormatException);
    });
  });
}
