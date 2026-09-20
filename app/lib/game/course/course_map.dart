import 'dart:math' as math;

import 'package:app/game/course/course_specs.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

export 'package:app/game/course/course_specs.dart';

part 'course_map_final.dart';
part 'course_map_json.dart';
part 'course_map_standard.dart';

// ---- Trap Race blueprint (map data, not physics tuning; library
// level so the part files share it) ----
const double _platformWidth = 6;
const double _platformHeight = 1;
const double _surfaceY = 0;
const double _killY = -6;
const double _spawnClearance = 0.01;
const double _backWallThickness = 0.3;
const double _backWallHeight = 3;
const double _finishWidth = 0.6;
const double _finishHeight = 3;
const double _finishSensorCenterHeight = 1;
const double _hammerJitter = 0.5;
const double _hammerRadius = 2;
const double _hammerAngularSpeed = 1.2;
const double _hammerPivotLift = 0.6;

/// Spawn anchor height: half a player plus clearance above the
/// surface.
double get _anchorHeight =>
    PlayerCharacter.heightMeters / 2 + _spawnClearance;

/// Data-only description of one course variant (architecture doc § 3:
/// map data is data, derived from the round seed).
@immutable
final class CourseMap {
  /// Creates a course from raw data.
  const CourseMap({
    required this.mapSeed,
    required this.spawnPoint,
    required this.checkpoints,
    required this.finishLine,
    required this.killY,
    required this.platforms,
    required this.walls,
    required this.hammers,
    this.spawnPoints = const [],
    this.movingWalls = const [],
  });

  /// Standard R1 course (trap-race.md § Level design): the
  /// five-segment program — runway, gap lane, hammer alley with an
  /// elevated safe lane, squeeze gates, downhill final stretch.
  /// Built in `course_map_standard.dart`; [mapSeed] jitters hammer
  /// pivots (±0.5 m), gap widths (±0.2 m) and wall phases
  /// deterministically.
  factory CourseMap.trapRace(int mapSeed) =>
      CourseMapStandardFactory.build(mapSeed);

  /// FINAL variant of Trap Race (`trap_race_final`): segments 2-4
  /// only, lane -60%, gaps 2.5 m, hammers 1.6 rad/s, no
  /// checkpoints, [starters] spawn slots (2-4). Built in
  /// `course_map_final.dart`.
  factory CourseMap.trapRaceFinal(int mapSeed, [int starters = 4]) =>
      CourseMapFinalFactory.build(mapSeed, starters);

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data. Lives in `course_map_json.dart`.
  factory CourseMap.fromJson(Map<String, Object?> json) =>
      CourseMapJson.fromJson(json);

  /// Seed this variant was derived from.
  final int mapSeed;

  /// Player spawn point (checkpoint 0 / respawn point 0).
  final Vector2 spawnPoint;

  /// Checkpoint positions in course order. Index i is respawn
  /// point i + 1; checkpoints may be triggered in any order but the
  /// respawn point is the highest index touched.
  final List<Vector2> checkpoints;

  /// Sensor box marking the finish line.
  final BoxSpec finishLine;

  /// Fall line: a player whose center goes below this y has fallen.
  final double killY;

  /// Static platform boxes.
  final List<BoxSpec> platforms;

  /// Static wall boxes (each at least
  /// `PhysicsConsts.minWallThickness` thick).
  final List<BoxSpec> walls;

  /// Rotating hammer specs.
  final List<HammerSpec> hammers;

  /// Per-slot spawn points for variant fields that spread starters
  /// (FINAL, 2-4 starters). Empty on variants that stack every
  /// starter on [spawnPoint]; [effectiveSpawnPoints] normalizes.
  final List<Vector2> spawnPoints;

  /// Sinusoidally oscillating squeeze-gate walls.
  final List<MovingWallSpec> movingWalls;

  /// Spawn slots in order: [spawnPoints] when the variant spreads
  /// them, otherwise a single [spawnPoint] slot.
  List<Vector2> get effectiveSpawnPoints =>
      spawnPoints.isEmpty ? [spawnPoint] : spawnPoints;

  /// JSON: every field; points serialize as `[x, y]` lists.
  Map<String, Object?> toJson() => <String, Object?>{
    'mapSeed': mapSeed,
    'spawnPoint': [spawnPoint.x, spawnPoint.y],
    'checkpoints': [
      for (final c in checkpoints) [c.x, c.y],
    ],
    'finishLine': finishLine.toJson(),
    'killY': killY,
    'platforms': [for (final p in platforms) p.toJson()],
    'walls': [for (final w in walls) w.toJson()],
    'hammers': [for (final h in hammers) h.toJson()],
    'spawnPoints': [
      for (final s in spawnPoints) [s.x, s.y],
    ],
    'movingWalls': [for (final w in movingWalls) w.toJson()],
  };

  @override
  bool operator ==(Object other) {
    if (other is! CourseMap ||
        other.mapSeed != mapSeed ||
        other.killY != killY ||
        other.spawnPoint.x != spawnPoint.x ||
        other.spawnPoint.y != spawnPoint.y ||
        other.finishLine != finishLine) {
      return false;
    }
    return _listEq(checkpoints, other.checkpoints, _pointEq) &&
        _listEq(platforms, other.platforms, (a, b) => a == b) &&
        _listEq(walls, other.walls, (a, b) => a == b) &&
        _listEq(hammers, other.hammers, (a, b) => a == b) &&
        _listEq(spawnPoints, other.spawnPoints, _pointEq) &&
        _listEq(movingWalls, other.movingWalls, (a, b) => a == b);
  }

  static bool _pointEq(Vector2 a, Vector2 b) => a.x == b.x && a.y == b.y;

  static bool _listEq<T>(List<T> a, List<T> b, bool Function(T, T) eq) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!eq(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    mapSeed,
    killY,
    spawnPoint.x,
    spawnPoint.y,
    finishLine,
    for (final c in checkpoints) ...[c.x, c.y],
    ...platforms,
    ...walls,
    ...hammers,
    for (final s in spawnPoints) ...[s.x, s.y],
    ...movingWalls,
  ]);

  @override
  String toString() =>
      'CourseMap(seed: $mapSeed, '
      'checkpoints: ${checkpoints.length}, hammers: ${hammers.length})';
}
