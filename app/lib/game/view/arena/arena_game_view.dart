import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/player_character.dart';
import 'package:app/game/round_simulation.dart';
import 'package:app/game/view/arena/arena_camera.dart';
import 'package:app/game/view/arena/arena_visuals.dart';
import 'package:app/game/view/race_game_view.dart'
    show maxStepsPerFrame, renderPixelsPerMeter;
import 'package:flame/game.dart' show Game;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

/// M1 placeholder palette shared by arena views (visual-only
/// constants, exempt from gameplay-constant rules).
abstract final class ArenaPalette {
  /// Arena backdrop.
  static const Color background = Color(0xFF101820);

  /// Remote player bodies.
  static const Color remotePlayer = Color(0xFF8D99AE);

  /// Local player body (distinct).
  static const Color localPlayer = Color(0xFFEF8354);
}

/// Flame view over an arena [RoundSimulation] (Hammer Dodge, King of
/// the Hill): steps the simulation at [PhysicsConsts.fixedDt] with
/// the same clamped accumulator policy as `RaceGameView` and draws
/// the arena purely from map data — Forge2D bodies are never touched
/// by the render path.
///
/// Elimination rendering rule (survival archetype): a player whose
/// [RoundSimulation.poseOf] is null (body destroyed) is simply not
/// drawn; no separate elimination set is kept.
final class ArenaGameView extends Game {
  /// Creates a view over a Hammer Dodge arena round.
  factory ArenaGameView.hammer({
    required RoundSimulation simulation,
    required HammerArenaMap map,
    required PlayerId localPlayerId,
    List<PlayerId> playerIds = const [],
    Map<PlayerId, PlayerInputState> Function()? tickInputsProvider,
    bool Function()? tickEnabled,
  }) => ArenaGameView._(
    simulation,
    localPlayerId,
    playerIds,
    tickInputsProvider,
    tickEnabled,
    HammerArenaVisuals(map),
  );

  /// Creates a view over a King of the Hill arena round.
  factory ArenaGameView.hill({
    required RoundSimulation simulation,
    required HillArenaMap map,
    required PlayerId localPlayerId,
    List<PlayerId> playerIds = const [],
    Map<PlayerId, PlayerInputState> Function()? tickInputsProvider,
    bool Function()? tickEnabled,
  }) => ArenaGameView._(
    simulation,
    localPlayerId,
    playerIds,
    tickInputsProvider,
    tickEnabled,
    HillArenaVisuals(map),
  );

  ArenaGameView._(
    this.simulation,
    this.localPlayerId,
    this.playerIds,
    this.tickInputsProvider,
    this.tickEnabled,
    this._visuals,
  );


  /// The round simulation stepped by this view's loop.
  final RoundSimulation simulation;

  /// Player followed by the camera and drawn distinct.
  final PlayerId localPlayerId;

  /// Rendered players; empty renders only [localPlayerId].
  final List<PlayerId> playerIds;

  /// Full per-tick input map (human + bots); players without an
  /// entry this tick idle. Null feeds an empty map (everyone idles).
  final Map<PlayerId, PlayerInputState> Function()? tickInputsProvider;

  /// Whether the loop may run another step; null always allows.
  final bool Function()? tickEnabled;

  /// Invoked after each completed simulation step.
  void Function()? onStep;

  final ArenaVisuals _visuals;

  double _accumulatorSeconds = 0;
  int _stepCount = 0;

  /// Camera clamp rectangle of this arena.
  @visibleForTesting
  ArenaCameraBounds get arenaBounds => _visuals.bounds;

  /// Total simulation steps performed by this view's loop.
  @visibleForTesting
  int get stepCount => _stepCount;

  /// Leftover frame time not yet consumed by a step.
  @visibleForTesting
  double get accumulatorSeconds => _accumulatorSeconds;

  /// Players drawn each frame (render order).
  List<PlayerId> get renderedPlayers =>
      playerIds.isEmpty ? [localPlayerId] : playerIds;

  /// Poses drawn this frame: every rendered player whose body still
  /// exists. Eliminated players (pose null) drop out.
  @visibleForTesting
  List<({PlayerId id, PlayerPose pose})> get renderPoses => [
    for (final id in renderedPlayers)
      if (simulation.poseOf(id) case final pose?) (id: id, pose: pose),
  ];

  /// Render angle of hammer arm [hammerIndex], radians. Hill arenas
  /// have no arms (RangeError on any index).
  @visibleForTesting
  double armAngleFor(int hammerIndex) {
    final hammers = _visuals.hammers;
    if (hammerIndex < 0 || hammerIndex >= hammers.length) {
      throw RangeError.index(hammerIndex, hammers, 'hammerIndex');
    }
    return hammerArmAngle(hammers[hammerIndex], _stepCount);
  }

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
      simulation.tickInputs(tickInputsProvider?.call() ?? const {});
      _stepCount++;
      onStep?.call();
      _accumulatorSeconds -= PhysicsConsts.fixedDt;
      steps++;
    }
    if (steps == maxStepsPerFrame) {
      // Spiral-of-death guard: drop the backlog instead of letting a
      // slow frame tax every following one.
      _accumulatorSeconds = 0;
    }
  }

  /// Camera focus for [focus] (meters) with a view of
  /// [viewSizeMeters], clamped so the visible rectangle stays inside
  /// [arenaBounds] whenever the arena is larger than the view.
  @visibleForTesting
  Vector2 cameraTargetFor(Vector2 focus, Vector2 viewSizeMeters) {
    final bounds = _visuals.bounds;
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
    final poses = renderPoses;
    PlayerPose? localPose;
    for (final entry in poses) {
      if (entry.id == localPlayerId) {
        localPose = entry.pose;
        break;
      }
    }
    final bounds = _visuals.bounds;
    final focus = localPose == null
        // No pose yet (eliminated local player, or before the first
        // tick): park the camera at the arena center.
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

    _visuals.draw(canvas, _stepCount);
    for (final entry in poses) {
      _drawPlayer(canvas, entry.id, entry.pose);
    }

    canvas.restore();
  }

  void _drawPlayer(Canvas canvas, PlayerId playerId, PlayerPose pose) {
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
  Color backgroundColor() => ArenaPalette.background;

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

final Paint _backgroundPaint = Paint()..color = ArenaPalette.background;
final Paint _remotePlayerPaint = Paint()..color = ArenaPalette.remotePlayer;
final Paint _localPlayerPaint = Paint()..color = ArenaPalette.localPlayer;
