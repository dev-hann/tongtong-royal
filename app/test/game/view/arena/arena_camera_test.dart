import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/view/arena/arena_camera.dart';
import 'package:app/game/view/race_game_view.dart'
    show cameraTopMarginMeters;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArenaCameraBounds.fromHammerMap', () {
    test('forms a square around the kill ring plus padding', () {
      final map = HammerArenaMap.hammerArena(7);
      final bounds = ArenaCameraBounds.fromHammerMap(map);

      final extent = map.killRadius + hammerCameraPaddingMeters;
      expect(bounds.minX, closeTo(-extent, 1e-9));
      expect(bounds.maxX, closeTo(extent, 1e-9));
      expect(bounds.minY, closeTo(-extent, 1e-9));
      expect(bounds.maxY, closeTo(extent, 1e-9));
    });
  });

  group('ArenaCameraBounds.fromHillMap', () {
    test('spans the floor slab sides, kill line bottom, crown-top ceiling', () {
      final map = HillArenaMap.kingOfTheHill(7);
      final bounds = ArenaCameraBounds.fromHillMap(map);

      expect(
        bounds.minX,
        closeTo(
          map.floor.center.x - map.floor.width / 2 - hillCameraSideMarginMeters,
          1e-9,
        ),
      );
      expect(
        bounds.maxX,
        closeTo(
          map.floor.center.x + map.floor.width / 2 + hillCameraSideMarginMeters,
          1e-9,
        ),
      );
      expect(bounds.minY, closeTo(map.killY, 1e-9));
      expect(bounds.maxY, closeTo(map.crownTopY + cameraTopMarginMeters, 1e-9));
    });
  });
}
