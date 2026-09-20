part of 'course_map.dart';

/// FINAL variant of Trap Race (`trap_race_final`, trap-race.md §
/// Level design): the standard course's segments 2-4 only — gap
/// lane, hammer alley, squeeze gates — with the lane width reduced
/// 60% (6 m -> 2.4 m platforms), gaps widened to 2.5 m, hammers
/// sped up to 1.6 rad/s and NO checkpoints (falls are final, the
/// variant's simulation mode decides that). Spawns spread across
/// the start platform for 2-4 starters.
final class CourseMapFinalFactory {
  /// Builds the FINAL course for [mapSeed] with [starters] spawn
  /// slots (2-4, GDD § 7.1 cascade tolerance).
  static CourseMap build(int mapSeed, [int starters = 4]) {
    if (starters < 2 || starters > 4) {
      throw ArgumentError.value(
        starters,
        'starters',
        'the FINAL supports 2-4 starters',
      );
    }
    final rng = math.Random(mapSeed);
    double hammerJitter() => (rng.nextDouble() * 2 - 1) * _hammerJitter;
    double gapJitter() => (rng.nextDouble() * 2 - 1) * _finalGapJitter;

    const lane = _finalLaneWidth;
    const surfaceY = _surfaceY;
    const centerY = surfaceY - _platformHeight / 2;

    final gapA = _finalGapWidth + gapJitter();
    final gapB = _finalGapWidth + gapJitter();

    // Segment 2 — gap lane: two widened pit gaps.
    const p0Right = lane;
    final p1Left = p0Right + gapA;
    final p1Right = p1Left + lane;
    final p2Left = p1Right + gapB;
    // Segment 3 — hammer alley: three contiguous platforms, two
    // phase-offset hammers at the variant speed.
    final p3Left = p2Left + lane;
    final p4Left = p3Left + lane;
    final p5Left = p4Left + lane;
    // Segment 4 — squeeze gates: three contiguous platforms, two
    // oscillating walls, finish sensor at the far end.
    final p6Left = p5Left + lane;
    final p7Left = p6Left + lane;
    final p8Left = p7Left + lane;

    BoxSpec slab(double left) => BoxSpec(
      center: Vector2(left + lane / 2, centerY),
      width: lane,
      height: _platformHeight,
    );

    const hammerPivotY =
        surfaceY + _hammerRadius + _hammerPivotLift;
    final wallPhaseJitter =
        (rng.nextDouble() * 2 - 1) * _finalWallPhaseJitterSeconds *
            2 *
        math.pi / _finalWallPeriodSeconds;

    return CourseMap(
      mapSeed: mapSeed,
      spawnPoint: Vector2(lane / 2, _anchorHeight),
      checkpoints: const [],
      finishLine: BoxSpec(
        center: Vector2(p8Left + lane * 3 / 4, _finishSensorCenterHeight),
        width: _finishWidth,
        height: _finishHeight,
      ),
      killY: _killY,
      platforms: [
        slab(0),
        slab(p1Left),
        slab(p2Left),
        slab(p3Left),
        slab(p4Left),
        slab(p5Left),
        slab(p6Left),
        slab(p7Left),
        slab(p8Left),
      ],
      walls: [
        BoxSpec(
          center: Vector2(
            -_backWallThickness / 2,
            surfaceY + _backWallHeight / 2 - _platformHeight / 2,
          ),
          width: _backWallThickness,
          height: _backWallHeight,
        ),
      ],
      hammers: [
        HammerSpec(
          pivot: Vector2(p3Left + lane / 2 + hammerJitter(), hammerPivotY),
          radius: _hammerRadius,
          angularSpeed: _finalHammerSpeed,
        ),
        HammerSpec(
          pivot: Vector2(p5Left + lane / 2 + hammerJitter(), hammerPivotY),
          radius: _hammerRadius,
          angularSpeed: _finalHammerSpeed,
          initialAngle: math.pi,
        ),
      ],
      spawnPoints: [
        for (var i = 0; i < starters; i++)
          Vector2(lane * (i + 0.5) / starters, _anchorHeight),
      ],
      movingWalls: [
        MovingWallSpec(
          center: Vector2(p6Left + lane / 2, _finalWallBaseY),
          width: _backWallThickness,
          height: _backWallHeight,
          amplitude: _finalWallAmplitude,
          period: _finalWallPeriodSeconds,
          phase: wallPhaseJitter,
        ),
        MovingWallSpec(
          center: Vector2(p7Left + lane / 2, _finalWallBaseY),
          width: _backWallThickness,
          height: _backWallHeight,
          amplitude: _finalWallAmplitude,
          period: _finalWallPeriodSeconds,
          phase: math.pi + wallPhaseJitter,
        ),
      ],
    );
  }
}

// ---- FINAL blueprint (map data, not physics tuning) ----

/// Lane-width reduction of the FINAL variant (60% off the 6 m
/// standard platform width).
const double _finalLaneReduction = 0.6;

/// FINAL platform width: `_platformWidth * (1 - _finalLaneReduction)`.
const double _finalLaneWidth = _platformWidth * (1 - _finalLaneReduction);

/// FINAL gap width before seed jitter, meters.
const double _finalGapWidth = 2.5;

/// FINAL hammer speed, rad/s.
const double _finalHammerSpeed = 1.6;

/// FINAL gap-width seed jitter, meters (schema ±0.2 m).
const double _finalGapJitter = 0.2;

/// Squeeze-gate oscillation amplitude, meters (game doc: 1.5 m).
const double _finalWallAmplitude = 1.5;

/// Squeeze-gate oscillation period, seconds (game doc amendment:
/// the period was unspecified; pinned here).
const double _finalWallPeriodSeconds = 3;

/// Squeeze-gate wall center y at the oscillation midpoint: wall
/// bottom peaks at `_finalWallBaseY - _backWallHeight / 2 +
/// _finalWallAmplitude` = 1.7 m, clearing the 1.5 m player by
/// 0.2 m when fully open.
const double _finalWallBaseY = 1.7;

/// Squeeze-gate phase seed jitter, fraction of one period.
const double _finalWallPhaseJitterSeconds = 0.25;
