import 'dart:math' as math;

import 'package:app/game/course/course_specs.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

export 'package:app/game/course/course_specs.dart';

/// Data-only description of one Hammer Dodge arena variant
/// (architecture doc § 3: map data is data, derived from the round
/// seed). A circular platform — approximated at build time by a
/// [platformSegmentCount]-sided regular polygon of static boxes —
/// with two counter-rotating hammer arms pivoting at the platform
/// center and a kill ring beyond the platform edge (GDD § 4.2).
@immutable
final class HammerArenaMap {
  /// Creates an arena from raw data.
  const HammerArenaMap({
    required this.mapSeed,
    required this.platformRadius,
    required this.platformSegmentCount,
    required this.platformThickness,
    required this.killRadius,
    required this.spawnPoints,
    required this.hammers,
  });

  /// Small but complete Hammer Dodge arena (GDD § 4.2): a circular
  /// platform whose circularity is approximated by 16 static boxes
  /// (a 16-sided regular polygon shell; N = 16 keeps every face
  /// within 11.25° of radial so the shell reads as round), two
  /// hammer arms on the platform center pivot — one long, one
  /// shorter, counter-rotating — sweeping the standable upper arc,
  /// and a kill radius just past where a standing player can reach.
  /// [mapSeed] jitters the hammer speeds and start angles
  /// deterministically.
  factory HammerArenaMap.hammerArena(int mapSeed) {
    final rng = math.Random(mapSeed);
    double speedJitter() => (rng.nextDouble() * 2 - 1) * _speedJitter;
    double phaseJitter() => (rng.nextDouble() * 2 - 1) * _phaseJitter;

    final apothem = _outerApothem;
    final spawnRadius = apothem + PlayerCharacter.heightMeters / 2 +
        _spawnClearance;

    return HammerArenaMap(
      mapSeed: mapSeed,
      platformRadius: _platformRadius,
      platformSegmentCount: _platformSegmentCount,
      platformThickness: _platformThickness,
      killRadius:
          _platformRadius + PlayerCharacter.heightMeters / 2 + _killMargin,
      spawnPoints: [
        for (final offsetDegrees in _spawnArcDegrees)
          _polar(spawnRadius, _topPoleDegrees + offsetDegrees),
      ],
      hammers: [
        HammerSpec(
          pivot: Vector2.zero(),
          radius: _platformRadius + _hammerTipOvershoot,
          angularSpeed: _innerHammerSpeed + speedJitter(),
          initialAngle: phaseJitter(),
        ),
        HammerSpec(
          pivot: Vector2.zero(),
          radius: _platformRadius - _hammerTipUndershoot,
          angularSpeed: -(_outerHammerSpeed + speedJitter()),
          initialAngle: math.pi + phaseJitter(),
        ),
      ],
    );
  }

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data.
  factory HammerArenaMap.fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('HammerArenaMap.$name is missing');
      }
      return value;
    }

    Vector2 point(Object? value, String name) {
      if (value is! List || value.length != 2) {
        throw FormatException('HammerArenaMap.$name must be [x, y]');
      }
      return Vector2(
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
      );
    }

    List<T> list<T>(Object? value, String name, T Function(Object?) parse) {
      if (value is! List) {
        throw FormatException('HammerArenaMap.$name must be a list');
      }
      return [for (final item in value) parse(item)];
    }

    int count(Object? value, String name) {
      if (value is! int) {
        throw FormatException('HammerArenaMap.$name must be an integer');
      }
      return value;
    }

    return HammerArenaMap(
      mapSeed: count(field('mapSeed'), 'mapSeed'),
      platformRadius: _asDouble(
        field('platformRadius'),
        'platformRadius',
      ),
      platformSegmentCount: count(
        field('platformSegmentCount'),
        'platformSegmentCount',
      ),
      platformThickness: _asDouble(
        field('platformThickness'),
        'platformThickness',
      ),
      killRadius: _asDouble(field('killRadius'), 'killRadius'),
      spawnPoints: list<Vector2>(
        field('spawnPoints'),
        'spawnPoints',
        (item) => point(item, 'spawnPoints'),
      ),
      hammers: list(
        field('hammers'),
        'hammers',
        (item) => HammerSpec.fromJson(_asObject(item)),
      ),
    );
  }

  // ---- Arena blueprint (map data, not physics tuning) ----
  static const double _platformRadius = 7;
  static const int _platformSegmentCount = 16;
  static const double _platformThickness = 1;
  static const double _killMargin = 0.5;
  static const double _spawnClearance = 0.01;
  static const double _innerHammerSpeed = 1.2;
  static const double _outerHammerSpeed = 1.7;
  static const double _hammerTipOvershoot = 0.1;
  static const double _hammerTipUndershoot = 0.1;
  static const double _speedJitter = 0.25;
  static const double _phaseJitter = math.pi / 6;
  static const double _topPoleDegrees = 90;
  static const List<double> _spawnArcDegrees = [-30, -10, 10, 30];

  /// Point at [radius] on the arc, [degrees] measured from +x axis.
  static Vector2 _polar(double radius, double degrees) => Vector2(
    radius * math.cos(degrees * math.pi / 180),
    radius * math.sin(degrees * math.pi / 180),
  );

  /// Radius of the outer face centers of the polygon shell: the
  /// flat faces sit at this radius, the corners slightly beyond.
  static double get _outerApothem =>
      (_platformRadius - _platformThickness / 2) *
          math.cos(math.pi / _platformSegmentCount) +
      _platformThickness / 2;

  /// Seed this variant was derived from.
  final int mapSeed;

  /// Outer surface radius of the platform, meters.
  final double platformRadius;

  /// Side count of the regular polygon approximating the circular
  /// platform (each side is one static box).
  final int platformSegmentCount;

  /// Radial thickness of each platform segment box, meters.
  final double platformThickness;

  /// A player whose center is farther than this from the platform
  /// center has fallen off the arena (eliminated, not respawned).
  final double killRadius;

  /// Spawn points on the upper platform arc, one per player slot.
  final List<Vector2> spawnPoints;

  /// Rotating hammer specs (pivot: platform center).
  final List<HammerSpec> hammers;

  /// JSON: every field; points serialize as `[x, y]` lists.
  Map<String, Object?> toJson() => <String, Object?>{
    'mapSeed': mapSeed,
    'platformRadius': platformRadius,
    'platformSegmentCount': platformSegmentCount,
    'platformThickness': platformThickness,
    'killRadius': killRadius,
    'spawnPoints': [
      for (final s in spawnPoints) [s.x, s.y],
    ],
    'hammers': [for (final h in hammers) h.toJson()],
  };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('HammerArenaMap.$field must be a number');
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
    if (other is! HammerArenaMap ||
        other.mapSeed != mapSeed ||
        other.platformRadius != platformRadius ||
        other.platformSegmentCount != platformSegmentCount ||
        other.platformThickness != platformThickness ||
        other.killRadius != killRadius) {
      return false;
    }
    return _listEq(spawnPoints, other.spawnPoints, _pointEq) &&
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
    platformRadius,
    platformSegmentCount,
    platformThickness,
    killRadius,
    for (final s in spawnPoints) ...[s.x, s.y],
    ...hammers,
  ]);

  @override
  String toString() =>
      'HammerArenaMap(seed: $mapSeed, radius: $platformRadius, '
      'segments: $platformSegmentCount, hammers: ${hammers.length})';
}
