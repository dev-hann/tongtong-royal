import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:app/design/tokens.dart' show ArenaPalette;
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/player_character.dart';
import 'package:app/net/remote/render_feed.dart';
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

/// Flame view over a [RaceSimulation] and/or a remote snapshot
/// stream.
///
/// Pure renderer/loop (architecture doc § 6). The view samples a
/// [RenderFeed] once per frame and draws what it gets. Two modes:
///
/// - **Local** (default): a [RaceSimulation] is injected and wrapped
///   in a [LocalRenderFeed]. The loop steps the simulation at
///   [PhysicsConsts.fixedDt] with a clamped accumulator, feeding it
///   the injected [InputSource] (remote players idle — M1 is
///   single-player).
/// - **Remote**: a prebuilt [RenderFeed] (see
///   `net/remote/RemoteRenderFeed`) is injected instead. No
///   simulation exists locally; the loop never steps anything, it
///   only samples interpolated snapshots plus local-player
///   prediction (architecture doc § 9).
///
/// Follows the local player with a bounds-clamped camera and draws
/// every course body as a colored rectangle. No rules, no judging —
/// raw [RoundEvent]s pass straight through.
final class RaceGameView extends Game {
  /// Creates a local view over [simulation] for [localPlayerId].
  ///
  /// [playerIds] lists the bodies to render; empty means only the
  /// local player (M1 single-player default). Subscribes to
  /// [RaceSimulation.events] until [onRemove].
  ///
  /// Alternatively, pass [renderFeed] to run in remote mode: the
  /// view then draws purely from that feed and never steps a
  /// simulation ([simulation] may be null). Exactly one of
  /// [simulation] and [renderFeed] must be provided.
  RaceGameView({
    required this.localPlayerId,
    required this.map,
    this.simulation,
    InputSource? inputSource,
    this.playerIds = const [],
    RenderFeed? renderFeed,
    this.tickInputsProvider,
    this.tickEnabled,
    this.palette = const ArenaPalette(),
  }) : assert(
         simulation != null || renderFeed != null,
         'either simulation or renderFeed must be provided',
       ),
       inputSource = inputSource ?? IdleInputSource(),
       renderFeed =
           renderFeed ??
           LocalRenderFeed(
             simulation: simulation!,
             map: map,
             localPlayerId: localPlayerId,
             playerIds: playerIds,
           ) {
    _eventSubscription = simulation?.events.listen(_onEvent);
  }

  /// The simulation stepped by this view in local mode; `null` in
  /// remote mode (nothing is simulated locally, architecture
  /// doc § 9).
  final RaceSimulation? simulation;

  /// Source of per-frame render state (local or remote).
  final RenderFeed renderFeed;

  /// Player followed by the camera and fed by [inputSource].
  final PlayerId localPlayerId;

  /// Course data used for camera bounds and static geometry.
  final CourseMap map;

  /// Where the per-tick local input comes from (local mode only).
  final InputSource inputSource;

  /// Rendered players; empty renders only [localPlayerId].
  final List<PlayerId> playerIds;

  /// Full per-tick input map for multi-seat hosts (human + bots):
  /// when provided, the loop feeds `tickInputs(provider())` instead
  /// of sampling [inputSource] for the local player only. Null keeps
  /// the single-player path default-identical.
  final Map<PlayerId, PlayerInputState> Function()? tickInputsProvider;

  /// Whether the loop may run another step. Checked before every
  /// step (multi-seat hosts freeze the loop once their round ended);
  /// null always allows.
  final bool Function()? tickEnabled;

  /// Render palette (design tokens); injectable for tests.
  final ArenaPalette palette;

  /// Invoked after each completed simulation step (multi-seat hosts
  /// run their post-tick bookkeeping here).
  void Function()? onStep;

  double _accumulatorSeconds = 0;
  int _stepCount = 0;
  bool _finished = false;
  StreamSubscription<RoundEvent>? _eventSubscription;

  late final Paint _backgroundPaint = Paint()..color = palette.background;
  late final Paint _platformPaint = Paint()..color = palette.platform;
  late final Paint _wallPaint = Paint()..color = palette.platformEdge;
  late final Paint _checkpointPaint = Paint()..color = palette.checkpoint;
  late final Paint _finishPaint = Paint()..color = palette.finishLine;
  late final Paint _hammerPaint = Paint()..color = palette.hazard;
  late final Paint _remotePlayerPaint = Paint()..color = palette.playerRemote;
  late final Paint _localPlayerPaint = Paint()..color = palette.playerLocal;

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
  /// doc § 2: emit, don't judge). Empty in remote mode (judged
  /// events travel over the wire, not through a local simulation).
  Stream<RoundEvent> get events =>
      simulation?.events ?? const Stream<RoundEvent>.empty();

  /// Players drawn each frame (render order).
  List<PlayerId> get renderedPlayers =>
      playerIds.isEmpty ? [localPlayerId] : playerIds;

  @override
  void update(double dt) {
    // Remote mode: no local simulation to step — rendering samples
    // the feed (architecture doc § 9).
    if (simulation == null) {
      return;
    }
    if (!dt.isFinite || dt <= 0) {
      return;
    }
    _accumulatorSeconds += dt;
    var steps = 0;
    while (_accumulatorSeconds >= PhysicsConsts.fixedDt &&
        steps < maxStepsPerFrame &&
        (tickEnabled?.call() ?? true)) {
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
    final sim = simulation;
    if (sim == null) {
      return;
    }
    final provider = tickInputsProvider;
    if (provider == null) {
      // Remote players get no entry, which idles them (M1: only the
      // local player exists anyway).
      sim.tickInputs({localPlayerId: inputSource.sample()});
    } else {
      // Multi-seat host path: the provider owns the full input map
      // (human + bots); players without an entry idle.
      sim.tickInputs(provider());
    }
    _stepCount++;
    onStep?.call();
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
    // Sample the feed once; everything below draws from this state.
    final state = renderFeed.sample();
    final localPose = state.players[localPlayerId];
    final bounds = courseBounds;
    final focus = localPose == null
        // No pose yet (e.g. remote before the first snapshot): park
        // the camera at the course center.
        ? Vector2(
            (bounds.minX + bounds.maxX) / 2,
            (bounds.minY + bounds.maxY) / 2,
          )
        : Vector2(localPose.x, localPose.y);
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
      _drawHammer(canvas, hammer, state.worldTick);
    }
    state.players.forEach((id, pose) => _drawPlayer(canvas, id, pose));

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

  void _drawHammer(Canvas canvas, HammerSpec hammer, int worldTick) {
    // Kinematic arms rotate at constant angular speed from angle 0,
    // so the world angle is speed * elapsed ticks * fixed dt; the
    // bodies themselves are not exposed by RaceSimulation. Works for
    // remote feeds too: their tick comes from the interpolated
    // snapshot.
    final angle = hammer.angularSpeed * worldTick * PhysicsConsts.fixedDt;
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

  void _drawPlayer(Canvas canvas, PlayerId playerId, PlayerRenderPose pose) {
    final paint = playerId == localPlayerId
        ? _localPlayerPaint
        : _remotePlayerPaint;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(pose.x, pose.y),
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
  Color backgroundColor() => palette.background;

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
