part of 'course_map.dart';

/// Standard R1 course (trap-race.md § Level design): the full
/// five-segment program — flat runway, gap lane with two pit gaps,
/// hammer alley with two phase-offset hammers and an elevated safe
/// lane, squeeze gates, downhill final stretch with the finish
/// sensor. Seeded jitter moves hammer pivots (±0.5 m), gap widths
/// (±0.2 m) and wall phases (±0.25 period); same seed → identical
/// course.
/// X landmarks of the standard course's segment boundaries.
typedef _Landmarks = ({
  /// Left edge of the first pit gap.
  double gap1Left,

  /// Right edge of the first pit gap.
  double gap1Right,

  /// Left edge of the second pit gap.
  double gap2Left,

  /// Right edge of the second pit gap.
  double gap2Right,

  /// Left edge of the hammer alley.
  double alleyLeft,

  /// Left edge of the elevated safe lane.
  double elevLeft,

  /// Left edge of the squeeze-gate segment.
  double gatesLeft,

  /// Left edge of the downhill final stretch.
  double downhillLeft,
});

/// Builds the standard R1 course variant from a seed (factory
/// pattern mirrors the FINAL's `CourseMapFinalFactory`).
final class CourseMapStandardFactory {
  /// Builds the standard course for [mapSeed].
  static CourseMap build(int mapSeed) {
    final rng = math.Random(mapSeed);
    final landmarks = _landmarks(
      gap1: _gapLaneGap1Width + _jitter(rng, _gapJitter),
      gap2: _gapLaneGap2Width + _jitter(rng, _gapJitter),
    );

    return CourseMap(
      mapSeed: mapSeed,
      spawnPoint: Vector2(_spawnX, _anchorHeight),
      checkpoints: _checkpoints(landmarks),
      finishLine: _finishLine(landmarks),
      killY: _killY,
      platforms: _platforms(landmarks),
      walls: [_backWall()],
      hammers: _hammers(landmarks, rng),
      movingWalls: _gates(landmarks, rng),
    );
  }

  static double _jitter(math.Random rng, double spread) =>
      (rng.nextDouble() * 2 - 1) * spread;

  /// X landmarks of every segment boundary: the gap-lane pit edges
  /// and each later segment's left edge.
  static _Landmarks _landmarks({required double gap1, required double gap2}) {
    const gap1Left = _runwayLength + _gapLaneSlab1Width;
    final gap1Right = gap1Left + gap1;
    final gap2Left = gap1Right + _gapLaneSlab2Width;
    final gap2Right = gap2Left + gap2;
    final alleyLeft = gap2Right + _gapLaneSlab3Width;
    return (
      gap1Left: gap1Left,
      gap1Right: gap1Right,
      gap2Left: gap2Left,
      gap2Right: gap2Right,
      alleyLeft: alleyLeft,
      elevLeft: alleyLeft + _alleyGroundWidth,
      gatesLeft: alleyLeft + _alleyTotalWidth,
      downhillLeft: alleyLeft + _alleyTotalWidth + _gateSegmentWidth,
    );
  }

  /// Surface slab helper: box whose top sits at [topY].
  static BoxSpec _slab(double left, double width, double topY) => BoxSpec(
    center: Vector2(left + width / 2, topY - _platformHeight / 2),
    width: width,
    height: _platformHeight,
  );

  /// Respawn checkpoints: after gap 1, after gap 2 (alley entry),
  /// after the alley (gates entry), after the gates (downhill
  /// entry). R1 respawns at the highest touched (trap-race.md §
  /// Qualification).
  static List<Vector2> _checkpoints(_Landmarks l) => [
    Vector2(l.gap1Right + 1, _anchorHeight),
    Vector2(l.gap2Right + 1, _anchorHeight),
    Vector2(l.gatesLeft + 1, _anchorHeight),
    Vector2(l.downhillLeft + 1, _anchorHeight),
  ];

  /// Segment 5 finish sensor: on the last downhill step, inset from
  /// the platform's right edge, one standing-player height above
  /// its surface.
  static BoxSpec _finishLine(_Landmarks l) {
    const lastSurface = _surfaceY - _stretchDropPerStep * _stretchStepCount;
    final lastRight =
        l.downhillLeft +
        _stretchSlab1Width +
        _stretchSlab2Width +
        _stretchSlab3Width;
    return BoxSpec(
      center: Vector2(
        lastRight - _finishInset,
        lastSurface + _finishSensorCenterHeight,
      ),
      width: _finishWidth,
      height: _finishHeight,
    );
  }

  /// All 13 slabs: 2 runway + 3 gap-lane + 3 alley (ground,
  /// elevated safe lane, ground) + 2 squeeze + 3 downhill steps.
  static List<BoxSpec> _platforms(_Landmarks l) => [
    _slab(0, _platformWidth, _surfaceY),
    _slab(_platformWidth, _platformWidth, _surfaceY),
    _slab(_runwayLength, _gapLaneSlab1Width, _surfaceY),
    _slab(l.gap1Right, _gapLaneSlab2Width, _surfaceY),
    _slab(l.gap2Right, _gapLaneSlab3Width, _surfaceY),
    _slab(l.alleyLeft, _alleyGroundWidth, _surfaceY),
    BoxSpec(
      center: Vector2(
        l.elevLeft + _elevatedLaneWidth / 2,
        _surfaceY + _elevatedLaneHeight / 2,
      ),
      width: _elevatedLaneWidth,
      height: _elevatedLaneHeight,
    ),
    _slab(l.elevLeft + _elevatedLaneWidth, _alleyGroundWidth, _surfaceY),
    _slab(l.gatesLeft, _gateSlabWidth, _surfaceY),
    _slab(l.gatesLeft + _gateSlabWidth, _gateSlabWidth, _surfaceY),
    _slab(l.downhillLeft, _stretchSlab1Width, _surfaceY),
    _slab(
      l.downhillLeft + _stretchSlab1Width,
      _stretchSlab2Width,
      _surfaceY - _stretchDropPerStep,
    ),
    _slab(
      l.downhillLeft + _stretchSlab1Width + _stretchSlab2Width,
      _stretchSlab3Width,
      _surfaceY - _stretchDropPerStep * _stretchStepCount,
    ),
  ];

  /// Start back wall sealing the runway's left edge.
  static BoxSpec _backWall() => BoxSpec(
    center: Vector2(
      -_backWallThickness / 2,
      _surfaceY + _backWallHeight / 2 - _platformHeight / 2,
    ),
    width: _backWallThickness,
    height: _backWallHeight,
  );

  /// Segment 3 hammers: one over each alley ground slab (pivot at
  /// the quarter mark), phase-offset by half a turn so their sweeps
  /// alternate; the elevated lane between them stays outside both
  /// sweep circles.
  static List<HammerSpec> _hammers(_Landmarks l, math.Random rng) {
    const pivotY = _surfaceY + _hammerRadius + _hammerPivotLift;
    return [
      HammerSpec(
        pivot: Vector2(
          l.alleyLeft + _alleyGroundWidth / 4 + _jitter(rng, _hammerJitter),
          pivotY,
        ),
        radius: _hammerRadius,
        angularSpeed: _hammerAngularSpeed,
      ),
      HammerSpec(
        pivot: Vector2(
          l.elevLeft +
              _elevatedLaneWidth +
              _alleyGroundWidth * 3 / 4 +
              _jitter(rng, _hammerJitter),
          pivotY,
        ),
        radius: _hammerRadius,
        angularSpeed: _hammerAngularSpeed,
        initialAngle: math.pi,
      ),
    ];
  }

  /// Segment 4 squeeze gates: one sinusoidal wall per slab,
  /// phase-opposed so they alternate closed phases (trap-race.md:
  /// stop-start rhythm).
  static List<MovingWallSpec> _gates(_Landmarks l, math.Random rng) {
    final phaseJitter =
        _jitter(rng, _gateWallPhaseJitterSeconds) *
        2 *
        math.pi /
        _gateWallPeriodSeconds;
    return [
      for (final (index, phase) in [0.0, math.pi].indexed)
        MovingWallSpec(
          center: Vector2(
            l.gatesLeft + _gateSlabWidth * (index + 0.5),
            _gateWallBaseY,
          ),
          width: _backWallThickness,
          height: _backWallHeight,
          amplitude: _gateWallAmplitude,
          period: _gateWallPeriodSeconds,
          phase: phase + phaseJitter,
        ),
    ];
  }
}

// ---- Standard-course blueprint (map data, not physics tuning) ----

/// Runway length, meters (trap-race.md segment 1: ~12 m).
const double _runwayLength = 12;

/// First pit gap width before seed jitter, meters (1.5 m).
const double _gapLaneGap1Width = 1.5;

/// Second pit gap width before seed jitter, meters (2 m).
const double _gapLaneGap2Width = 2;

/// Pit-gap width seed jitter, meters (schema ±0.2 m).
const double _gapJitter = 0.2;

/// Gap-lane slab widths, meters: before gap 1 / between / after
/// (totals ~20 m with the gaps).
const double _gapLaneSlab1Width = 5.5;
const double _gapLaneSlab2Width = 6;
const double _gapLaneSlab3Width = 6.5;

/// Hammer-alley ground slab width flanking the elevated lane,
/// meters (alley totals 18 m).
const double _alleyGroundWidth = 6;

/// Full hammer-alley width: two ground slabs + the safe lane.
const double _alleyTotalWidth = 2 * _alleyGroundWidth + _elevatedLaneWidth;

/// Squeeze-gate segment total width, meters (14 m over two slabs).
const double _gateSegmentWidth = 2 * _gateSlabWidth;

/// Elevated safe lane width, meters.
const double _elevatedLaneWidth = 6;

/// Elevated safe lane height, meters — the platform top sits 1 m
/// above the surface, reachable by the standard jump (physics doc
/// ~1.2 m apex) and outside both hammer sweep circles.
const double _elevatedLaneHeight = 1;

/// Squeeze-gate slab width, meters (two slabs per segment).
const double _gateSlabWidth = 7;

/// Squeeze-gate oscillation amplitude, meters (game doc: 1.5 m).
const double _gateWallAmplitude = 1.5;

/// Squeeze-gate oscillation period, seconds (pinned 2026-09-19).
const double _gateWallPeriodSeconds = 3;

/// Squeeze-gate wall center y at the oscillation midpoint: fully
/// open the wall bottom clears a 1.5 m player by 0.2 m.
const double _gateWallBaseY = 1.7;

/// Squeeze-gate phase seed jitter, fraction of one period.
const double _gateWallPhaseJitterSeconds = 0.25;

/// Final-stretch step widths, meters (segment totals ~10 m).
const double _stretchSlab1Width = 4;
const double _stretchSlab2Width = 3;
const double _stretchSlab3Width = 3;

/// Final-stretch descent per step, meters.
const double _stretchDropPerStep = 0.5;

/// Final-stretch descending steps after the first slab.
const int _stretchStepCount = 2;

/// Finish sensor inset from the last platform's right edge, meters.
const double _finishInset = 0.75;

/// Spawn x on the runway, meters.
const double _spawnX = 3;
