import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/view/arena/arena_camera.dart';
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
}
