import 'dart:math' as math;

import 'package:app/game/course/course_specs.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

export 'package:app/game/course/course_specs.dart';

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
  });

  /// Small but complete Trap Race course (GDD § 4.1): start platform
  /// with a back wall, three gaps with a checkpoint after each of the
  /// first three platforms, one seeded rotating hammer over platform
  /// B, finish sensor on the last platform. [mapSeed] jitters the
  /// hammer pivot by up to ±0.5 m deterministically.
  factory CourseMap.trapRace(int mapSeed) {
    final rng = math.Random(mapSeed);
    final hammerJitter = (rng.nextDouble() * 2 - 1) * _hammerJitter;

    const platformCenterY = _surfaceY - _platformHeight / 2;
    final platforms = List<BoxSpec>.generate(4, (i) {
      return BoxSpec(
        center: Vector2(i * _platformStep, platformCenterY),
        width: _platformWidth,
        height: _platformHeight,
      );
    });

    final firstPlatform = platforms.first;
    return CourseMap(
      mapSeed: mapSeed,
      spawnPoint: Vector2(firstPlatform.center.x, _anchorHeight),
      checkpoints: [
        for (var i = 1; i <= 3; i++)
          Vector2(
            i == 3
                ? platforms[3].center.x - _platformWidth / 4
                : platforms[i].center.x,
            _anchorHeight,
          ),
      ],
      finishLine: BoxSpec(
        center: Vector2(
          platforms[3].center.x + _platformWidth / 4,
          _finishSensorCenterHeight,
        ),
        width: _finishWidth,
        height: _finishHeight,
      ),
      killY: _killY,
      platforms: platforms,
      walls: [
        BoxSpec(
          center: Vector2(
            firstPlatform.center.x -
                _platformWidth / 2 -
                _backWallThickness / 2,
            _surfaceY + _backWallHeight / 2 - _platformHeight / 2,
          ),
          width: _backWallThickness,
          height: _backWallHeight,
        ),
      ],
      hammers: [
        HammerSpec(
          // Pivot sits `_hammerPivotLift` above the height where the
          // arm tip would graze the surface, so the sweep catches a
          // standing player's torso.
          pivot: Vector2(
            platforms[1].center.x + hammerJitter,
            _surfaceY + _hammerRadius + _hammerPivotLift,
          ),
          radius: _hammerRadius,
          angularSpeed: _hammerAngularSpeed,
        ),
      ],
    );
  }

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data.
  factory CourseMap.fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('CourseMap.$name is missing');
      }
      return value;
    }

    Vector2 point(Object? value, String name) {
      if (value is! List || value.length != 2) {
        throw FormatException('CourseMap.$name must be [x, y]');
      }
      return Vector2(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
    }

    List<T> list<T>(Object? value, String name, T Function(Object?) parse) {
      if (value is! List) {
        throw FormatException('CourseMap.$name must be a list');
      }
      return [for (final item in value) parse(item)];
    }

    return CourseMap(
      mapSeed: field('mapSeed')! as int,
      spawnPoint: point(field('spawnPoint'), 'spawnPoint'),
      checkpoints: list<Vector2>(
        field('checkpoints'),
        'checkpoints',
        (item) => point(item, 'checkpoints'),
      ),
      finishLine: BoxSpec.fromJson(_asObject(field('finishLine'))),
      killY: (field('killY')! as num).toDouble(),
      platforms: list(
        field('platforms'),
        'platforms',
        (item) => BoxSpec.fromJson(_asObject(item)),
      ),
      walls: list(
        field('walls'),
        'walls',
        (item) => BoxSpec.fromJson(_asObject(item)),
      ),
      hammers: list(
        field('hammers'),
        'hammers',
        (item) => HammerSpec.fromJson(_asObject(item)),
      ),
    );
  }

  // ---- Trap Race blueprint (map data, not physics tuning) ----
  static const double _platformWidth = 6;
  static const double _platformHeight = 1;
  static const double _platformStep = 9;
  static const double _surfaceY = 0;
  static const double _killY = -6;
  static const double _spawnClearance = 0.01;
  static const double _backWallThickness = 0.3;
  static const double _backWallHeight = 3;
  static const double _finishWidth = 0.6;
  static const double _finishHeight = 3;
  static const double _finishSensorCenterHeight = 1;
  static const double _hammerJitter = 0.5;
  static const double _hammerRadius = 2;
  static const double _hammerAngularSpeed = 1.5;
  static const double _hammerPivotLift = 0.6;

  static double get _anchorHeight =>
      PlayerCharacter.heightMeters / 2 + _spawnClearance;

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
  };

  static Map<String, Object?> _asObject(Object? value) {
    if (value is! Map) {
      throw const FormatException('expected a JSON object');
    }
    return value.map((k, v) => MapEntry(k as String, v));
  }

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
        _listEq(hammers, other.hammers, (a, b) => a == b);
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
  ]);

  @override
  String toString() =>
      'CourseMap(seed: $mapSeed, '
      'checkpoints: ${checkpoints.length}, hammers: ${hammers.length})';
}
