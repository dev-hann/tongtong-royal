import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/player_character.dart';
import 'package:flame/game.dart' show Game;
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

/// Engine constant: maximum simulation steps per rendered frame
/// (spiral-of-death clamp). When a frame's accumulated time would
/// demand more steps, the surplus accumulator time is discarded so a
/// slow frame cannot snowball into an ever-growing backlog. Engine
/// constant, not gameplay tuning.
const int maxStepsPerFrame = 5;

/// Engine constant: render scale, logical pixels per world meter.
/// Pure display constant (M1 has no sprites; bodies draw as colored
/// rectangles).
const double renderPixelsPerMeter = 48;

/// Engine constant: extra meters kept in view above the highest
/// course geometry so the camera never hugs the ceiling boxes.
const double cameraTopMarginMeters = 1;

/// Engine constant: on-screen thickness of a checkpoint marker
/// (meters). Display-only.
const double checkpointMarkerWidthMeters = 0.2;

/// Engine constant: on-screen height of a checkpoint marker
/// (meters). Display-only.
const double checkpointMarkerHeightMeters = 2.5;

/// Engine constant: radius of the hammer pivot dot (meters).
/// Display-only.
const double hammerPivotDotRadiusMeters = 0.15;

/// M1 placeholder palette: colored rectangles stand in for sprites
/// (visual-only constants, exempt from gameplay-constant rules).
abstract final class RaceGamePalette {
  /// Course backdrop.
  static const Color background = Color(0xFF101820);

  /// Static platforms.
  static const Color platform = Color(0xFF3E5C76);

  /// Static walls.
  static const Color wall = Color(0xFF2C3E50);

  /// Checkpoint markers.
  static const Color checkpoint = Color(0xFF7FC8A9);

  /// Finish sensor.
  static const Color finish = Color(0xFFFFD166);

  /// Rotating hammers.
  static const Color hammer = Color(0xFFB23A48);

  /// Remote player bodies.
  static const Color remotePlayer = Color(0xFF8D99AE);

  /// Local player body (distinct).
  static const Color localPlayer = Color(0xFFEF8354);
}

final Paint _backgroundPaint = Paint()..color = RaceGamePalette.background;
final Paint _platformPaint = Paint()..color = RaceGamePalette.platform;
final Paint _wallPaint = Paint()..color = RaceGamePalette.wall;
final Paint _checkpointPaint = Paint()..color = RaceGamePalette.checkpoint;
final Paint _finishPaint = Paint()..color = RaceGamePalette.finish;
final Paint _hammerPaint = Paint()..color = RaceGamePalette.hammer;
final Paint _remotePlayerPaint = Paint()..color = RaceGamePalette.remotePlayer;
final Paint _localPlayerPaint = Paint()..color = RaceGamePalette.localPlayer;

/// Producer of one [PlayerInputState] per simulation tick. Abstracts
/// where input comes from (touch overlay now, keyboard/netcode later)
/// so the game loop itself never touches gestures.
// Single-method seam kept deliberately: it is the injectable input
// boundary required by the architecture, not an accidental class.
// ignore: one_member_abstracts
abstract interface class InputSource {
  /// Returns the input to apply on the tick about to be simulated.
  /// Edge flags (jump/dash) must be true for exactly one sample.
  PlayerInputState sample();
}

/// [InputSource] used when none is injected: reports idle input.
final class IdleInputSource implements InputSource {
  @override
  PlayerInputState sample() => PlayerInputState();
}

/// Immutable world-space rectangle the camera is clamped to,
/// derived from [CourseMap] data only.
@immutable
final class CourseCameraBounds {
  /// Creates bounds from raw extents.
  const CourseCameraBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  /// Computes the camera bounds of [map]: x extents over all
  /// platforms and walls, bottom at the fall line, top above the
  /// highest box plus [cameraTopMarginMeters].
  factory CourseCameraBounds.fromMap(CourseMap map) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final box in [...map.platforms, ...map.walls]) {
      minX = math.min(minX, box.center.x - box.width / 2);
      maxX = math.max(maxX, box.center.x + box.width / 2);
      maxY = math.max(maxY, box.center.y + box.height / 2);
    }
    return CourseCameraBounds(
      minX: minX,
      maxX: maxX,
      minY: map.killY,
      maxY: maxY + cameraTopMarginMeters,
    );
  }

  /// Left edge, meters.
  final double minX;

  /// Right edge, meters.
  final double maxX;

  /// Bottom edge, meters (fall line).
  final double minY;

  /// Top edge, meters.
  final double maxY;
}

/// Flame view over a running [RaceSimulation].
///
/// Pure renderer/loop (architecture doc § 6): steps the simulation
/// at [PhysicsConsts.fixedDt] with a clamped accumulator, reads local
/// input from an injected [InputSource] (remote players idle — M1 is
/// single-player), follows the local player with a bounds-clamped
/// camera and draws every course body as a colored rectangle. No
/// rules, no judging — raw [RoundEvent]s pass straight through.
final class RaceGameView extends Game {
  /// Creates the view over [simulation] for [localPlayerId].
  ///
  /// [playerIds] lists the bodies to render; empty means only the
  /// local player (M1 single-player default). Subscribes to
  /// [RaceSimulation.events] until [onRemove].
  RaceGameView({
    required this.simulation,
    required this.localPlayerId,
    required this.map,
    InputSource? inputSource,
    this.playerIds = const [],
  }) : inputSource = inputSource ?? IdleInputSource() {
    _eventSubscription = simulation.events.listen(_onEvent);
  }

  /// The simulation stepped and rendered by this view.
  final RaceSimulation simulation;

  /// Player followed by the camera and fed by [inputSource].
  final PlayerId localPlayerId;

  /// Course data used for camera bounds and static geometry.
  final CourseMap map;

  /// Where the per-tick local input comes from.
  final InputSource inputSource;

  /// Rendered players; empty renders only [localPlayerId].
  final List<PlayerId> playerIds;

  double _accumulatorSeconds = 0;
  int _stepCount = 0;
  bool _finished = false;
  StreamSubscription<RoundEvent>? _eventSubscription;

  /// Camera clamp rectangle for [map].
  @visibleForTesting
  CourseCameraBounds get courseBounds => CourseCameraBounds.fromMap(map);

  /// Total simulation steps performed by this view's loop.
  @visibleForTesting
  int get stepCount => _stepCount;

  /// Leftover frame time not yet consumed by a step.
  @visibleForTesting
  double get accumulatorSeconds => _accumulatorSeconds;

  /// True once any [PlayerFinished] event was observed.
  bool get finished => _finished;

  /// Passthrough of the simulation's raw events (architecture
  /// doc § 2: emit, don't judge).
  Stream<RoundEvent> get events => simulation.events;

  /// Players drawn each frame (render order).
  List<PlayerId> get renderedPlayers =>
      playerIds.isEmpty ? [localPlayerId] : playerIds;

  @override
  void update(double dt) {
    if (!dt.isFinite || dt <= 0) {
      return;
    }
    _accumulatorSeconds += dt;
    var steps = 0;
    while (_accumulatorSeconds >= PhysicsConsts.fixedDt &&
        steps < maxStepsPerFrame) {
      _stepSimulation();
      _accumulatorSeconds -= PhysicsConsts.fixedDt;
      steps++;
    }
    if (steps == maxStepsPerFrame) {
      // Spiral-of-death guard: drop the backlog instead of letting a
      // slow frame tax every following one.
      _accumulatorSeconds = 0;
    }
  }

  void _stepSimulation() {
    // Remote players get no entry, which idles them (M1: only the
    // local player exists anyway).
    simulation.tickInputs({localPlayerId: inputSource.sample()});
    _stepCount++;
  }

  void _onEvent(RoundEvent event) {
    if (event is PlayerFinished) {
      _finished = true;
    }
  }

  /// Camera focus for [focus] (meters) with a view of
  /// [viewSizeMeters], clamped so the visible rectangle stays inside
  /// [courseBounds] whenever the course is larger than the view.
  @visibleForTesting
  Vector2 cameraTargetFor(Vector2 focus, Vector2 viewSizeMeters) {
    final bounds = courseBounds;
    return Vector2(
      _axisClamp(focus.x, viewSizeMeters.x / 2, bounds.minX, bounds.maxX),
      _axisClamp(focus.y, viewSizeMeters.y / 2, bounds.minY, bounds.maxY),
    );
  }

  @override
  void render(Canvas canvas) {
    if (!hasLayout) {
      return;
    }
    canvas.drawRect(Offset.zero & Size(size.x, size.y), _backgroundPaint);
    final viewSizeMeters = Vector2(
      size.x / renderPixelsPerMeter,
      size.y / renderPixelsPerMeter,
    );
    final focus = simulation.bodyOf(localPlayerId).position;
    final camera = cameraTargetFor(focus, viewSizeMeters);

    canvas
      ..save()
      // World units: y up, origin at the camera target, scaled to
      // pixels (the negative y scale flips Forge2D's up axis onto
      // the screen's down axis).
      ..translate(size.x / 2, size.y / 2)
      ..scale(renderPixelsPerMeter, -renderPixelsPerMeter)
      ..translate(-camera.x, -camera.y);

    for (final platform in map.platforms) {
      _drawBox(canvas, platform, _platformPaint);
    }
    for (final wall in map.walls) {
      _drawBox(canvas, wall, _wallPaint);
    }
    for (final checkpoint in map.checkpoints) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(checkpoint.x, checkpoint.y),
          width: checkpointMarkerWidthMeters,
          height: checkpointMarkerHeightMeters,
        ),
        _checkpointPaint,
      );
    }
    _drawBox(canvas, map.finishLine, _finishPaint);
    for (final hammer in map.hammers) {
      _drawHammer(canvas, hammer);
    }
    for (final playerId in renderedPlayers) {
      _drawPlayer(canvas, playerId);
    }

    canvas.restore();
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

  void _drawHammer(Canvas canvas, HammerSpec hammer) {
    // Kinematic arms rotate at constant angular speed from angle 0,
    // so the world angle is speed * elapsed ticks * fixed dt; the
    // bodies themselves are not exposed by RaceSimulation.
    final angle =
        hammer.angularSpeed * simulation.currentTick * PhysicsConsts.fixedDt;
    canvas
      ..save()
      ..translate(hammer.pivot.x, hammer.pivot.y)
      ..rotate(angle)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(hammer.radius / 2, 0),
          width: hammer.radius,
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

  void _drawPlayer(Canvas canvas, PlayerId playerId) {
    final body = simulation.bodyOf(playerId);
    final paint = playerId == localPlayerId
        ? _localPlayerPaint
        : _remotePlayerPaint;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(body.position.x, body.position.y),
        width: PlayerCharacter.widthMeters,
        height: PlayerCharacter.heightMeters,
      ),
      paint,
    );
  }

  @override
  void onRemove() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  Color backgroundColor() => const Color(0xFF101820);

  static double _axisClamp(
    double focus,
    double halfExtent,
    double min,
    double max,
  ) {
    if (max - min <= 2 * halfExtent) {
      return (min + max) / 2;
    }
    final lower = min + halfExtent;
    final upper = max - halfExtent;
    if (focus < lower) {
      return lower;
    }
    if (focus > upper) {
      return upper;
    }
    return focus;
  }
}
