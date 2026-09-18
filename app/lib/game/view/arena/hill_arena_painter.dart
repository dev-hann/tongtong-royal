import 'dart:ui' show Canvas, Color, Offset, Paint, Rect;

import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/course/course_specs.dart' show BoxSpec;

/// Engine constant: on-screen thickness of the highlighted crown
/// zone on the platform top surface, meters. Display-only.
const double crownZoneHighlightThicknessMeters = 0.12;

/// Engine constant: on-screen thickness of the kill-floor hint
/// strip, meters. Display-only.
const double killFloorHintThicknessMeters = 0.25;

/// M1 placeholder palette for the hill arena (visual-only constants,
/// exempt from gameplay-constant rules).
abstract final class HillArenaPalette {
  /// Main floor slab.
  static const Color floor = Color(0xFF3E5C76);

  /// Static ramp steps.
  static const Color ramp = Color(0xFF2C3E50);

  /// Crown platform (distinct from the floor).
  static const Color crown = Color(0xFFFFD166);

  /// Highlighted crown zone on the platform top surface.
  static const Color crownZone = Color(0xFFEF8354);

  /// Kill-floor hint strip.
  static const Color killFloor = Color(0xFF1B2631);
}

final Paint _floorPaint = Paint()..color = HillArenaPalette.floor;
final Paint _rampPaint = Paint()..color = HillArenaPalette.ramp;
final Paint _crownPaint = Paint()..color = HillArenaPalette.crown;
final Paint _crownZonePaint = Paint()..color = HillArenaPalette.crownZone;
final Paint _killFloorPaint = Paint()..color = HillArenaPalette.killFloor;

/// Draws a King of the Hill arena in world coordinates (call under
/// the view's meter/y-flip transform). Geometry comes from map data
/// only.
void drawHillArena({required Canvas canvas, required HillArenaMap map}) {
  _drawBox(canvas, map.floor, _floorPaint);
  for (final ramp in map.ramps) {
    _drawBox(canvas, ramp, _rampPaint);
  }
  _drawBox(canvas, map.crownPlatform, _crownPaint);
  _drawCrownZone(canvas, map);
  _drawKillFloorHint(canvas, map);
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
void _drawCrownZone(Canvas canvas, HillArenaMap map) {
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(map.crownCenter.x, map.crownTopY),
      width: map.crownRadius * 2,
      height: crownZoneHighlightThicknessMeters,
    ),
    _crownZonePaint,
  );
}

/// Kill floor hint: dark strip at the fall line spanning the floor
/// slab width.
void _drawKillFloorHint(Canvas canvas, HillArenaMap map) {
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(map.floor.center.x, map.killY),
      width: map.floor.width,
      height: killFloorHintThicknessMeters,
    ),
    _killFloorPaint,
  );
}
