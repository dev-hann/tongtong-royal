import 'package:app/game/arenas/hill/hill_arena_builder.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/character_world.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';

void main() {
  group('HillArenaBuilder', () {
    test('builds_floor_crown_platform_and_four_ramps', () {
      final world = CharacterWorld();
      HillArenaBuilder.build(world, HillArenaMap.kingOfTheHill(7));

      // floor + crown platform + 4 ramp steps, nothing else.
      expect(world.forgeWorld.bodies, hasLength(6));
    });

    test('player_on_crown_top_is_grounded', () {
      final world = CharacterWorld();
      final map = HillArenaMap.kingOfTheHill(7);
      HillArenaBuilder.build(world, map);

      final player = world.spawnPlayer(
        position: Vector2(
          map.crownCenter.x,
          map.crownTopY + PlayerCharacter.heightMeters / 2 + 0.01,
        ),
      );
      for (var i = 0; i < 5; i++) {
        world.step();
      }

      expect(player.grounded, isTrue);
    });

    test('player_on_floor_is_grounded', () {
      final world = CharacterWorld();
      final map = HillArenaMap.kingOfTheHill(7);
      HillArenaBuilder.build(world, map);

      final player = world.spawnPlayer(
        position: Vector2(
          -5,
          map.floor.center.y +
              map.floor.height / 2 +
              PlayerCharacter.heightMeters / 2 +
              0.01,
        ),
      );
      for (var i = 0; i < 5; i++) {
        world.step();
      }

      expect(player.grounded, isTrue);
    });
  });
}
