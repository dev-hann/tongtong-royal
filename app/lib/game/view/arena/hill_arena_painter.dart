import 'dart:ui' show Canvas, Offset, Paint, Rect;

import 'package:app/design/tokens.dart' show ArenaPalette;
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/course/course_specs.dart' show BoxSpec;

/// Engine constant: on-screen thickness of the highlighted crown
/// zone on the platform top surface, meters. Display-only.
const double crownZoneHighlightThicknessMeters = 0.12;

/// Engine constant: on-screen thickness of the kill-floor hint
/// strip, meters. Display-only.
const double killFloorHintThicknessMeters = 0.25;

/// Draws a King of the Hill arena in world coordinates (call under
/// the view's meter/y-flip transform). Geometry comes from map data
/// only; colors come from the design tokens via [palette]
/// (injectable for tests).
void drawHillArena({
  required Canvas canvas,
  required HillArenaMap map,
  ArenaPalette palette = const ArenaPalette(),
}) {
  final floorPaint = Paint()..color = palette.platform;
  final rampPaint = Paint()..color = palette.platformEdge;
  final crownPaint = Paint()..color = palette.crownZone;
  final crownZonePaint = Paint()..color = palette.crownZoneHighlight;
  final killFloorPaint = Paint()..color = palette.killZoneHint;

  _drawBox(canvas, map.floor, floorPaint);
  for (final ramp in map.ramps) {
    _drawBox(canvas, ramp, rampPaint);
  }
  _drawBox(canvas, map.crownPlatform, crownPaint);
  _drawCrownZone(canvas, map, crownZonePaint);
  _drawKillFloorHint(canvas, map, killFloorPaint);
}

void _drawBox(Canvas canvas, BoxSpec box, Paint paint) {
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(box.center.x, box.center.y),
      width: box.width,
      height: box.height,
    ),
    paint,
  );
}

/// Crown zone hint: thin bright strip on the crown platform's top
/// surface spanning the scoring radius.
void _drawCrownZone(Canvas canvas, HillArenaMap map, Paint paint) {
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(map.crownCenter.x, map.crownTopY),
      width: map.crownRadius * 2,
      height: crownZoneHighlightThicknessMeters,
    ),
    paint,
  );
}

/// Kill floor hint: dark strip at the fall line spanning the floor
/// slab width.
void _drawKillFloorHint(Canvas canvas, HillArenaMap map, Paint paint) {
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(map.floor.center.x, map.killY),
      width: map.floor.width,
      height: killFloorHintThicknessMeters,
    ),
    paint,
  );
}
