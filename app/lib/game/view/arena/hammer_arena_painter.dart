import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Path, Rect;

import 'package:app/design/tokens.dart' show ArenaPalette;
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/view/race_game_view.dart'
    show hammerPivotDotRadiusMeters;

/// Draws a Hammer Dodge arena in world coordinates (call under the
/// view's meter/y-flip transform). Static geometry comes from map
/// data only; [armAngles] carries each arm's current render angle in
/// radians (one per [HammerArenaMap.hammers] entry, map order).
/// Colors come from the design tokens via [palette] (injectable for
/// tests).
void drawHammerArena({
  required Canvas canvas,
  required HammerArenaMap map,
  required List<double> armAngles,
  ArenaPalette palette = const ArenaPalette(),
}) {
  final platformPaint = Paint()..color = palette.platform;
  final killRimPaint = Paint()
    ..color = palette.killZoneHint
    ..style = PaintingStyle.stroke;
  final armPaint = Paint()..color = palette.hazard;

  _drawKillRim(canvas, map, killRimPaint);
  _drawPlatform(canvas, map, platformPaint);
  for (var i = 0; i < map.hammers.length; i++) {
    _drawArm(canvas, map.hammers[i], armAngles[i], armPaint);
  }
}

/// Kill ring hint: a dark stroked annulus between the platform edge
/// and the kill radius (radii derived from map data).
void _drawKillRim(Canvas canvas, HammerArenaMap map, Paint paint) {
  final rimRadius = (map.platformRadius + map.killRadius) / 2;
  canvas.drawCircle(
    Offset.zero,
    rimRadius,
    paint..strokeWidth = map.killRadius - map.platformRadius,
  );
}

/// The standable platform as a filled regular polygon (same segment
/// count the physics shell approximates the circle with).
void _drawPlatform(Canvas canvas, HammerArenaMap map, Paint paint) {
  final path = Path();
  final segmentAngle = 2 * math.pi / map.platformSegmentCount;
  for (var i = 0; i < map.platformSegmentCount; i++) {
    final vertex = Offset.fromDirection(i * segmentAngle, map.platformRadius);
    if (i == 0) {
      path.moveTo(vertex.dx, vertex.dy);
    } else {
      path.lineTo(vertex.dx, vertex.dy);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}

/// One arm: a rect along the local +x axis rotated to [angle], plus
/// the pivot dot (mirrors the fixture the builder sweeps).
void _drawArm(Canvas canvas, HammerSpec spec, double angle, Paint paint) {
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
      paint,
    )
    ..restore()
    ..drawCircle(
      Offset(spec.pivot.x, spec.pivot.y),
      hammerPivotDotRadiusMeters,
      paint,
    );
}
