import 'dart:math' as math;

import 'package:app/design/tokens.dart';
import 'package:flutter/widgets.dart';

/// Pose vocabulary of the jelly character (guide § 9.1): squash and
/// stretch on jump/land, ragdoll spin on elimination.
enum JellyPose {
  /// Resting breathe (subtle vertical scale wobble driven by the
  /// caller's `phase`).
  idle,

  /// Airborne stretch: tall + narrow.
  jump,

  /// Landing bounce: wide + short, relaxing back with the caller's
  /// `phase`.
  land,

  /// Eliminated: spinning with dizzy eyes.
  eliminated,
}

/// Squash/stretch factors per pose (guide § 4 motion scales applied
/// to character art; amplitude tokens live here because character
/// art is its own subsystem — values are art constants, not gameplay
/// tuning).
const Map<JellyPose, (double, double)> _poseScales = {
  JellyPose.idle: (1, 1),
  JellyPose.jump: (0.85, 1.15),
  JellyPose.land: (1.15, 0.85),
  JellyPose.eliminated: (1, 1),
};

/// Idle breathing amplitude (vertical scale wobble).
const double _breatheAmplitude = 0.02;

/// Blob corner roundness relative to half width.
const double _blobRoundness = 0.62;

/// Eye geometry as fractions of the blob size: offsets from center
/// and radii. Two-dot faces stay readable at thumbnail size (guide
/// § 9.1 — faces are 2-4 primitives max).
const double _eyeOffsetX = 0.17;
const double _eyeOffsetY = 0.12;
const double _eyeRadius = 0.055;

/// Local-player ring stroke width as a fraction of size.
const double _ringWidth = 0.045;

/// Draws one jelly character into [bounds] (any unit — logical px on
/// shell screens, world meters inside game views after the canvas
/// transform). Pure function of its inputs: callers animate by
/// redrawing with a new [phase]; no controllers or tickers inside
/// (design purity, guide § 9.2).
///
/// Palette law: [body] comes from [PlayerPalette], the eye/outline
/// colors from the shared tokens — no free colors here.
void drawJelly(
  Canvas canvas,
  Rect bounds, {
  required Color body,
  JellyPose pose = JellyPose.idle,
  double phase = 0,
  bool blink = false,
  bool isLocal = false,
}) {
  final (baseSx, baseSy) = _poseScales[pose]!;
  var sx = baseSx;
  var sy = baseSy;
  if (pose == JellyPose.idle) {
    sy = 1 + _breatheAmplitude * math.sin(2 * math.pi * phase);
  } else if (pose == JellyPose.land) {
    // Relax from the squash back toward rest as phase runs 0 → 1.
    final relax = phase.clamp(0.0, 1.0);
    sx = 1 + (baseSx - 1) * (1 - relax);
    sy = 1 + (baseSy - 1) * (1 - relax);
  }

  canvas
    ..save()
    ..translate(bounds.center.dx, bounds.center.dy);
  if (pose == JellyPose.eliminated) {
    canvas.rotate(2 * math.pi * phase);
  }
  canvas.scale(sx, sy);
  final half = bounds.shortestSide / 2;
  final blob = Rect.fromCircle(center: Offset.zero, radius: half);

  // Local marker: white ring slightly outside the body (guide § 9.1
  // — the local player keeps the shell's ring).
  if (isLocal) {
      final ringPaint = Paint()
      ..color = PlayerPalette.localRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = half * _ringWidth;
    canvas.drawCircle(Offset.zero, half * (1 + _ringWidth), ringPaint);
  }

  final bodyPaint = Paint()..color = body;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      blob,
      Radius.circular(blob.width * _blobRoundness),
    ),
    bodyPaint,
  );

  _drawFace(canvas, half, blink: blink, dizzy: pose == JellyPose.eliminated);

  canvas.restore();
}

/// Two-dot eyes (blinking: shut lines; eliminated: dizzy X marks).
void _drawFace(
  Canvas canvas,
  double half, {
  required bool blink,
  required bool dizzy,
}) {
  final eyePaint = Paint()..color = ColorPalette.neutral900;
  for (final directionX in const [-1.0, 1.0]) {
    final center = Offset(
      directionX * half * _eyeOffsetX * 2,
      -half * _eyeOffsetY * 2,
    );
    if (dizzy) {
      _drawX(canvas, center, half * _eyeRadius * 1.4, eyePaint);
    } else if (blink) {
      canvas.drawLine(
        center.translate(-half * _eyeRadius, 0),
        center.translate(half * _eyeRadius, 0),
        eyePaint..strokeWidth = half * _eyeRadius * 0.6,
      );
    } else {
      canvas.drawCircle(center, half * _eyeRadius, eyePaint);
    }
  }
}

void _drawX(Canvas canvas, Offset center, double arm, Paint paint) {
  paint
    ..strokeWidth = arm * 0.4
    ..style = PaintingStyle.stroke;
  canvas
    ..drawLine(
      center.translate(-arm, -arm),
      center.translate(arm, arm),
      paint,
    )
    ..drawLine(center.translate(-arm, arm), center.translate(arm, -arm), paint);
}

/// Widget-side painter over the `drawJelly` primitive (QUALIFY_FLASH
/// chips, tests, any future shell cameo). The blob fills `size`.
@immutable
final class JellyCharacterPainter extends CustomPainter {
  /// Creates a painter for one jelly.
  const JellyCharacterPainter({
    required this.body,
    this.pose = JellyPose.idle,
    this.phase = 0,
    this.blink = false,
    this.isLocal = false,
  });

  /// Body color (a [PlayerPalette] value).
  final Color body;

  /// Pose state (guide § 9.1).
  final JellyPose pose;

  /// Animation phase 0..1 (breathe wobble, land relax, spin angle).
  final double phase;

  /// Whether the eyes are shut this frame.
  final bool blink;

  /// Whether this is the local player (white ring).
  final bool isLocal;

  @override
  void paint(Canvas canvas, Size size) {
    drawJelly(
      canvas,
      Offset.zero & size,
      body: body,
      pose: pose,
      phase: phase,
      blink: blink,
      isLocal: isLocal,
    );
  }

  @override
  bool shouldRepaint(JellyCharacterPainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.pose != pose ||
      oldDelegate.phase != phase ||
      oldDelegate.blink != blink ||
      oldDelegate.isLocal != isLocal;
}
