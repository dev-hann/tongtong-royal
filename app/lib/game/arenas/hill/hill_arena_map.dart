import 'dart:math' as math;

import 'package:app/game/course/course_specs.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

/// Data-only description of one King of the Hill arena variant
/// (architecture doc § 3: map data is data, derived from the round
/// seed). One open floor slab, one elevated crown platform with a
/// seeded-jittered crown center, stepped ramps on both sides.
@immutable
final class HillArenaMap {
  /// Creates an arena from raw data.
  const HillArenaMap({
    required this.mapSeed,
    required this.spawnPoints,
    required this.floor,
    required this.crownCenter,
    required this.crownRadius,
    required this.crownHeight,
    required this.ramps,
    required this.killY,
  });

  /// Small but complete King of the Hill arena (GDD § 4.3): open
  /// floor, one crown platform the player can jump onto, a two-step
  /// staircase (four ramp boxes) on each side of the platform.
  /// [mapSeed] jitters the crown center by up to ±0.5 m
  /// deterministically.
  factory HillArenaMap.kingOfTheHill(int mapSeed) {
    final rng = math.Random(mapSeed);
    final crownJitterX = (rng.nextDouble() * 2 - 1) * _crownJitter;
    final crownCenter = Vector2(
      crownJitterX,
      _floorSurfaceY + _crownHeight,
    );

    final floor = BoxSpec(
      center: Vector2(0, _floorSurfaceY - _floorHeight / 2),
      width: _floorWidth,
      height: _floorHeight,
    );
    // Two step boxes per side of the platform form a climbable
    // staircase (side-view 2D: ramps are steps, four in total).
    const innerX = _crownRadius + _rampWidth / 2;
    const outerX = _crownRadius + _rampWidth * 1.5;
    final ramps = [
      for (final (ox, h) in [
        (innerX, _rampInnerHeight),
        (-innerX, _rampInnerHeight),
        (outerX, _rampOuterHeight),
        (-outerX, _rampOuterHeight),
      ])
        BoxSpec(
          center: Vector2(crownCenter.x + ox, _floorSurfaceY + h / 2),
          width: _rampWidth,
          height: h,
        ),
    ];

    return HillArenaMap(
      mapSeed: mapSeed,
      spawnPoints: [
        for (final x in _spawnXs) Vector2(x, _anchorHeight),
      ],
      floor: floor,
      crownCenter: crownCenter,
      crownRadius: _crownRadius,
      crownHeight: _crownHeight,
      ramps: ramps,
      killY: _killY,
    );
  }

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data.
  factory HillArenaMap.fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('HillArenaMap.$name is missing');
      }
      return value;
    }

    Vector2 point(Object? value, String name) {
      if (value is! List || value.length != 2) {
        throw FormatException('HillArenaMap.$name must be [x, y]');
      }
      return Vector2(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
    }

    List<T> list<T>(Object? value, String name, T Function(Object?) parse) {
      if (value is! List) {
        throw FormatException('HillArenaMap.$name must be a list');
      }
      return [for (final item in value) parse(item)];
    }

    return HillArenaMap(
      mapSeed: field('mapSeed')! as int,
      spawnPoints: list<Vector2>(
        field('spawnPoints'),
        'spawnPoints',
        (item) => point(item, 'spawnPoints'),
      ),
      floor: BoxSpec.fromJson(_asObject(field('floor'))),
      crownCenter: point(field('crownCenter'), 'crownCenter'),
      crownRadius: _asDouble(field('crownRadius'), 'crownRadius'),
      crownHeight: _asDouble(field('crownHeight'), 'crownHeight'),
      ramps: list(
        field('ramps'),
        'ramps',
        (item) => BoxSpec.fromJson(_asObject(item)),
      ),
      killY: _asDouble(field('killY'), 'killY'),
    );
  }

  // ---- Arena blueprint (map data, not physics tuning) ----
  static const double _floorWidth = 20;
  static const double _floorHeight = 1;
  static const double _floorSurfaceY = 0;
  static const double _crownRadius = 1.5;
  static const double _crownHeight = 1;
  static const double _crownJitter = 0.5;
  static const double _rampWidth = 1.2;
  static const double _rampInnerHeight = 0.7;
  static const double _rampOuterHeight = 0.4;
  static const double _killY = -6;
  static const double _spawnClearance = 0.01;
  static const List<double> _spawnXs = [-6, -2, 2, 6];

  static double get _anchorHeight =>
      PlayerCharacter.heightMeters / 2 + _spawnClearance;

  /// Seed this variant was derived from.
  final int mapSeed;

  /// Floor spawn points (respawn anchors), one per player slot.
  final List<Vector2> spawnPoints;

  /// The main floor slab.
  final BoxSpec floor;

  /// Center of the crown zone on the platform's top surface.
  final Vector2 crownCenter;

  /// Scoring radius around [crownCenter], meters.
  final double crownRadius;

  /// Height of the crown platform's top surface above the floor
  /// surface, meters. Kept within jump apex (~1.2 m) so the platform
  /// is climbable by a plain jump.
  final double crownHeight;

  /// Static ramp boxes around the crown platform.
  final List<BoxSpec> ramps;

  /// Fall line: a player whose center goes below this y has fallen
  /// off the world and respawns on the main floor.
  final double killY;

  /// The crown platform box (top surface at [crownTopY], spanning
  /// [crownRadius] to each side of [crownCenter]).
  BoxSpec get crownPlatform => BoxSpec(
        center: Vector2(
          crownCenter.x,
          crownTopY - crownHeight / 2,
        ),
        width: crownRadius * 2,
        height: crownHeight,
      );

  /// Y of the crown platform's top surface.
  double get crownTopY => crownCenter.y;

  /// Y of the floor's top surface.
  double get floorSurfaceY => floor.center.y + floor.height / 2;

  /// JSON: every field; points serialize as `[x, y]` lists.
  Map<String, Object?> toJson() => <String, Object?>{
        'mapSeed': mapSeed,
        'spawnPoints': [
          for (final s in spawnPoints) [s.x, s.y],
        ],
        'floor': floor.toJson(),
        'crownCenter': [crownCenter.x, crownCenter.y],
        'crownRadius': crownRadius,
        'crownHeight': crownHeight,
        'ramps': [for (final r in ramps) r.toJson()],
        'killY': killY,
      };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('HillArenaMap.$field must be a number');
    }
    return value.toDouble();
  }

  static Map<String, Object?> _asObject(Object? value) {
    if (value is! Map) {
      throw const FormatException('expected a JSON object');
    }
    return value.map((k, v) => MapEntry(k as String, v));
  }

  @override
  bool operator ==(Object other) {
    if (other is! HillArenaMap ||
        other.mapSeed != mapSeed ||
        other.crownRadius != crownRadius ||
        other.crownHeight != crownHeight ||
        other.killY != killY ||
        other.crownCenter.x != crownCenter.x ||
        other.crownCenter.y != crownCenter.y ||
        other.floor != floor) {
      return false;
    }
    return _listEq(spawnPoints, other.spawnPoints, _pointEq) &&
        _listEq(ramps, other.ramps, (a, b) => a == b);
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
        crownRadius,
        crownHeight,
        killY,
        crownCenter.x,
        crownCenter.y,
        floor,
        for (final s in spawnPoints) ...[s.x, s.y],
        ...ramps,
      ]);

  @override
  String toString() =>
      'HillArenaMap(seed: $mapSeed, crown: $crownCenter, '
      'radius: $crownRadius, ramps: ${ramps.length})';
}
