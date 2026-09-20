import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:app/design/game_art/jelly_primitives.dart';
import 'package:app/design/tokens.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/player_character.dart';
import 'package:app/game/view/race_game_view.dart'
    show IdleInputSource, InputSource, groundedSpeedEpsilonMeters,
        maxStepsPerFrame;
import 'package:flame/game.dart' show Game;
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Engine constant: world margin kept in view beyond the kill ring
/// (meters) so flung bodies stay on screen.
const double hammerViewMarginMeters = 1.5;

/// Engine constant: on-screen thickness of the kill aura ring
/// (meters). Display-only.
const double hammerKillAuraWidthMeters = 0.5;

/// Engine constant: radius of the mallet pivot dot (meters).
const double hammerPivotDotRadiusMeters = 0.15;

/// Flame view over a `HammerSimulation`: fixed camera on the arena
/// center, stepped at the fixed rate with the same clamped
/// accumulator policy as the race view (multi-seat hosts feed
/// `tickInputsProvider`, freeze via `tickEnabled`, run bookkeeping in
/// `onStep`). Pure renderer/loop — no rules, raw events pass
/// through untouched.
final class HammerGameView extends Game {
  /// Creates a local view over [simulation] for [localPlayerId] with
  /// every rendered seat in [playerIds] and its seat colors.
  HammerGameView({
    required this.simulation,
    required this.localPlayerId,
    required this.map,
    this.playerIds = const [],
    this.playerColors = const {},
    this.tickInputsProvider,
    this.tickEnabled,
    this.palette = const ArenaPalette(),
    InputSource? inputSource,
  }) : inputSource = inputSource ?? IdleInputSource();

  /// The arena simulation stepped by this view.
  final HammerSimulation simulation;

  /// Player followed by the ring highlight and fed by [inputSource].
  final PlayerId localPlayerId;

  /// Arena data (platform radii, mallet specs, shrink schedule).
  final HammerArenaMap map;

  /// Rendered players, render order.
  final List<PlayerId> playerIds;

  /// Seat colors per player (a [PlayerPalette] value each).
  final Map<PlayerId, Color> playerColors;

  /// Full per-tick input map (human + bots); when null the loop
  /// feeds only the local player's sample.
  final Map<PlayerId, PlayerInputState> Function()? tickInputsProvider;

  /// Whether the loop may run another step; null always allows.
  final bool Function()? tickEnabled;

  /// Render palette (design tokens); injectable for tests.
  final ArenaPalette palette;

  /// Where the local player's per-tick input comes from.
  final InputSource inputSource;

  /// Invoked after each completed simulation step (host-side
  /// bookkeeping, same seam as the race view's onStep).
  void Function()? onStep;

  double _accumulatorSeconds = 0;
  int _stepCount = 0;

  late final Paint _backgroundPaint = Paint()..color = palette.background;
  late final Paint _platformPaint = Paint()..color = palette.platform;
  late final Paint _slabPaint = Paint()..color = palette.platformEdge;
  late final Paint _auraPaint = Paint()
    ..color = palette.killZoneHint
    ..style = PaintingStyle.stroke;
  late final Paint _hammerPaint = Paint()..color = palette.hazard;

  /// Total simulation steps performed by this view's loop.
  @visibleForTesting
  int get stepCount => _stepCount;

  @override
  void update(double dt) {
    if (!dt.isFinite || dt <= 0) {
      return;
    }
    _accumulatorSeconds += dt;
    var steps = 0;
    while (_accumulatorSeconds >= PhysicsConsts.fixedDt &&
        steps < maxStepsPerFrame &&
        (tickEnabled?.call() ?? true)) {
      final provider = tickInputsProvider;
      if (provider == null) {
        simulation.tick(localPlayerId, inputSource.sample());
      } else {
        simulation.tickInputs(provider());
      }
      _stepCount++;
      steps++;
      _accumulatorSeconds -= PhysicsConsts.fixedDt;
      onStep?.call();
    }
    if (steps == maxStepsPerFrame) {
      // Spiral-of-death guard (same policy as the race view).
      _accumulatorSeconds = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!hasLayout) {
      return;
    }
    canvas.drawRect(
      Offset.zero & Size(size.x, size.y),
      _backgroundPaint,
    );
    final pixelsPerMeter =
        math.min(size.x, size.y) /
        (2 *
            (map.platformRadius +
                map.killRingMargin +
                hammerViewMarginMeters));

    canvas
      ..save()
      ..translate(size.x / 2, size.y / 2)
      ..scale(pixelsPerMeter, -pixelsPerMeter);

    // Platform: the stepped disc at its current (shrinking) radius,
    // plus the kill aura — a dark ring beyond the rim (kill-zone
    // language, guide § 9.2).
    final currentRadius = simulation.currentShrinkRadius;
    _auraPaint.strokeWidth = hammerKillAuraWidthMeters;
    // Center slab sealing the cone.
    canvas
      ..drawCircle(Offset.zero, currentRadius, _platformPaint)
      ..drawCircle(Offset.zero, map.killRadiusFor(currentRadius), _auraPaint)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(
            map.centerSlab.center.x,
            map.centerSlab.center.y,
          ),
          width: map.centerSlab.width,
          height: map.centerSlab.height,
        ),
        _slabPaint,
      );

    for (final hammer in map.hammers) {
      _drawMallet(canvas, hammer);
    }
    for (final playerId in playerIds) {
      _drawPlayer(canvas, playerId);
    }

    canvas.restore();
  }

  /// Kinematic mallet: banded head arm rotating from its initial
  /// angle at constant speed (same deterministic kinematics as the
  /// bot observations in the driver), chunky pivot dot.
  void _drawMallet(Canvas canvas, HammerSpec hammer) {
    final angle =
        hammer.initialAngle +
        hammer.angularSpeed * simulation.currentTick * PhysicsConsts.fixedDt;
    final headLength = hammer.headLength ?? hammer.radius;
    canvas
      ..save()
      ..translate(hammer.pivot.x, hammer.pivot.y)
      ..rotate(angle)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(hammer.radius - headLength / 2, 0),
          width: headLength,
          height: hammer.armThickness,
        ),
        _hammerPaint,
      )
      ..restore()
      ..drawCircle(
        Offset(hammer.pivot.x, hammer.pivot.y),
        hammerPivotDotRadiusMeters,
        _hammerPaint,
      );
  }

  /// Jelly player at its physics pose (guide § 9.1): airborne bodies
  /// stretch, grounded ones breathe by the world tick.
  void _drawPlayer(Canvas canvas, PlayerId playerId) {
    final pose = simulation.poseOf(playerId);
    if (pose == null) {
      return; // eliminated — the body is gone
    }
    final airborne = pose.vy.abs() > groundedSpeedEpsilonMeters;
    drawJelly(
      canvas,
      Rect.fromCenter(
        center: Offset(pose.x, pose.y),
        width: PlayerCharacter.widthMeters,
        height: PlayerCharacter.heightMeters,
      ),
      body:
          playerColors[playerId] ??
          (playerId == localPlayerId
              ? palette.playerLocal
              : palette.playerRemote),
      pose: airborne ? JellyPose.jump : JellyPose.idle,
      phase: (simulation.currentTick % PhysicsConsts.tickRate) /
          PhysicsConsts.tickRate,
      blink: simulation.currentTick % blinkPeriodTicks < blinkDurationTicks,
      isLocal: playerId == localPlayerId,
    );
  }

  /// Blink cadence period: shut eyes for ~0.2 s every ~3 s (art
  /// constant, guide § 9.1).
  static const int blinkPeriodTicks = 3 * PhysicsConsts.tickRate;

  /// Blink shut duration in ticks.
  static const int blinkDurationTicks = 12;

  @override
  Color backgroundColor() => palette.background;
}
