import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/view/race_game_view.dart'
    show hammerPivotDotRadiusMeters;

/// M1 placeholder palette for the hammer arena (visual-only
/// constants, exempt from gameplay-constant rules).
abstract final class HammerArenaPalette {
  /// Standable polygon platform.
  static const Color platform = Color(0xFF3E5C76);

  /// Kill ring rim (darker outer band past the platform edge).
  static const Color killRim = Color(0xFF1B2631);

  /// Rotating hammer arms and pivot dots.
  static const Color arm = Color(0xFFB23A48);
}

final Paint _platformPaint = Paint()..color = HammerArenaPalette.platform;
final Paint _killRimPaint = Paint()
  ..color = HammerArenaPalette.killRim
  ..style = PaintingStyle.stroke;
final Paint _armPaint = Paint()..color = HammerArenaPalette.arm;

/// Draws a Hammer Dodge arena in world coordinates (call under the
/// view's meter/y-flip transform). Static geometry comes from map
/// data only; [armAngles] carries each arm's current render angle in
/// radians (one per [HammerArenaMap.hammers] entry, map order).
void drawHammerArena({
  required Canvas canvas,
  required HammerArenaMap map,
  required List<double> armAngles,
}) {
  _drawKillRim(canvas, map);
  _drawPlatform(canvas, map);
  for (var i = 0; i < map.hammers.length; i++) {
    _drawArm(canvas, map.hammers[i], armAngles[i]);
  }
}

/// Kill ring hint: a dark stroked annulus between the platform edge
/// and the kill radius (radii derived from map data).
void _drawKillRim(Canvas canvas, HammerArenaMap map) {
  final rimRadius = (map.platformRadius + map.killRadius) / 2;
  canvas.drawCircle(
    Offset.zero,
    rimRadius,
    _killRimPaint..strokeWidth = map.killRadius - map.platformRadius,
  );
}

/// The standable platform as a filled regular polygon (same segment
/// count the physics shell approximates the circle with).
void _drawPlatform(Canvas canvas, HammerArenaMap map) {
  final path = Path();
  final segmentAngle = 2 * math.pi / map.platformSegmentCount;
  for (var i = 0; i < map.platformSegmentCount; i++) {
    final vertex = Offset.fromDirection(
      i * segmentAngle,
      map.platformRadius,
    );
    if (i == 0) {
      path.moveTo(vertex.dx, vertex.dy);
    } else {
      path.lineTo(vertex.dx, vertex.dy);
    }
  }
  path.close();
  canvas.drawPath(path, _platformPaint);
}

/// One arm: a rect along the local +x axis rotated to [angle], plus
/// the pivot dot (mirrors the fixture the builder sweeps).
void _drawArm(Canvas canvas, HammerSpec spec, double angle) {
  canvas
    ..save()
    ..translate(spec.pivot.x, spec.pivot.y)
    ..rotate(angle)
    ..drawRect(
      Rect.fromCenter(
        center: Offset(spec.radius / 2, 0),
        width: spec.radius,
        height: spec.armThickness,
      ),
      _armPaint,
    )
    ..restore()
    ..drawCircle(
      Offset(spec.pivot.x, spec.pivot.y),
      hammerPivotDotRadiusMeters,
      _armPaint,
    );
}
