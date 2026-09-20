import 'dart:math' as math;

import 'package:app/game/arenas/hammer/shrink_schedule.dart';
import 'package:app/game/course/course_specs.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

export 'package:app/game/course/course_specs.dart';

part 'hammer_map_json.dart';

/// Data-only description of one Hammer Dodge arena variant
/// (architecture doc § 3: map data is data, derived from the round
/// seed). A stepped circular platform — a 16-sided polygon shell per
/// shrink tier, plus a center slab sealing the interior — with two
/// counter-rotating mallet arms pivoting at the platform center and
/// a kill radius beyond the (shrinking) rim (hammer-dodge.md § Level
/// design).
@immutable
final class HammerArenaMap {
  /// Creates an arena from raw data.
  const HammerArenaMap({
    required this.mapSeed,
    required this.platformRadius,
    required this.platformSegmentCount,
    required this.platformThickness,
    required this.killRingMargin,
    required this.shrink,
    required this.centerSlab,
    required this.spawnPoints,
    required this.hammers,
  });

  /// Hammer Dodge arena per the game doc: a 7 m radius stepped
  /// platform shrinking to 4.5 m from 30 s over 15 s (five radius
  /// tiers; outer tiers drop as the rim passes them), a center slab
  /// whose ledge carries the spawn slots, and two counter-rotating
  /// mallet heads sweeping the 7.1 m / 6.9 m bands. [mapSeed]
  /// jitters the mallet speeds (±0.25 rad/s) and phases (±30°)
  /// deterministically.
  factory HammerArenaMap.hammerArena(int mapSeed) {
    final rng = math.Random(mapSeed);
    double speedJitter() => (rng.nextDouble() * 2 - 1) * _speedJitter;
    double phaseJitter() => (rng.nextDouble() * 2 - 1) * _phaseJitter;

    final shrink = ShrinkSchedule(
      startSeconds: _shrinkStartSeconds,
      durationSeconds: _shrinkDurationSeconds,
      endRadius: _shrunkRadius,
      tierCount: _shrinkTierCount,
    );
    final tiers = shrink.tierRadii(_platformRadius);
    final tierStep = tiers[0] - tiers[1];
    final slabTop = tiers.last - tierStep;
    // The slab reaches past the innermost tier's inner polygon edge
    // so no annular gap remains inside the settled platform.
    final slab = BoxSpec(
      center: Vector2(0, slabTop - _platformThickness / 2),
      width: tiers.last * 2,
      height: _platformThickness,
    );
    final spawnY = slabTop + PlayerCharacter.heightMeters / 2 +
        _spawnClearance;

    return HammerArenaMap(
      mapSeed: mapSeed,
      platformRadius: _platformRadius,
      platformSegmentCount: _platformSegmentCount,
      platformThickness: _platformThickness,
      killRingMargin: _killMargin,
      shrink: shrink,
      centerSlab: slab,
      spawnPoints: [
        for (final offsetX in _spawnOffsetX)
          Vector2(offsetX, spawnY),
      ],
      hammers: [
        HammerSpec(
          pivot: Vector2.zero(),
          radius: _platformRadius + _hammerTipOvershoot,
          angularSpeed: _innerHammerSpeed + speedJitter(),
          initialAngle: phaseJitter(),
          headLength: _malletHeadLength,
        ),
        HammerSpec(
          pivot: Vector2.zero(),
          radius: _platformRadius - _hammerTipUndershoot,
          angularSpeed: -(_outerHammerSpeed + speedJitter()),
          initialAngle: math.pi + phaseJitter(),
          headLength: _malletHeadLength,
        ),
      ],
    );
  }

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data. Lives in `hammer_map_json.dart`.
  factory HammerArenaMap.fromJson(Map<String, Object?> json) =>
      HammerArenaMapJson.fromJson(json);

  // ---- Arena blueprint (map data, not physics tuning) ----
  static const double _platformRadius = 7;
  static const int _platformSegmentCount = 16;
  static const double _platformThickness = 0.4;
  static const double _killMargin = 0.5;
  static const double _spawnClearance = 0.01;
  static const double _shrinkStartSeconds = 30;
  static const double _shrinkDurationSeconds = 15;
  static const double _shrunkRadius = 4.5;
  static const int _shrinkTierCount = 5;
  static const double _innerHammerSpeed = 1.2;
  static const double _outerHammerSpeed = 1.7;
  static const double _hammerTipOvershoot = 0.1;
  static const double _hammerTipUndershoot = 0.1;
  static const double _malletHeadLength = 0.6;
  static const double _speedJitter = 0.25;
  static const double _phaseJitter = math.pi / 6;

  /// Spawn slot offsets along the center slab ledge (four slots: the
  /// nominal 3-player round plus the tolerated fourth starter, GDD
  /// § 4 cascade note).
  static const List<double> _spawnOffsetX = [-2.1, -0.7, 0.7, 2.1];

  /// Seed this variant was derived from.
  final int mapSeed;

  /// Outer surface radius of the platform before shrinking, meters.
  final double platformRadius;

  /// Side count of the regular polygon approximating each circular
  /// platform tier (each side is one static box).
  final int platformSegmentCount;

  /// Radial thickness of each platform segment box, meters.
  final double platformThickness;

  /// Margin beyond the rim (plus half a player height) where the
  /// kill radius sits; the kill radius follows the shrinking rim.
  final double killRingMargin;

  /// Shrink schedule driving tier drops and the kill radius.
  final ShrinkSchedule shrink;

  /// Solid box sealing the platform interior so the stepped tiers
  /// form a standable cone down to the settled platform radius.
  final BoxSpec centerSlab;

  /// Spawn points on the center slab ledge, one per player slot.
  final List<Vector2> spawnPoints;

  /// Rotating mallet specs (pivot: platform center).
  final List<HammerSpec> hammers;

  /// Kill radius for a platform currently at [currentRadius]: the
  /// rim plus half a player plus the margin (a player whose center
  /// is farther out has fallen off, hammer-dodge.md § Level design).
  double killRadiusFor(double currentRadius) =>
      currentRadius +
      PlayerCharacter.heightMeters / 2 +
      killRingMargin;

  /// Initial kill radius (pre-shrink rim).
  double get initialKillRadius => killRadiusFor(platformRadius);

  /// JSON: every field; points serialize as `[x, y]` lists.
  Map<String, Object?> toJson() => <String, Object?>{
    'mapSeed': mapSeed,
    'platformRadius': platformRadius,
    'platformSegmentCount': platformSegmentCount,
    'platformThickness': platformThickness,
    'killRingMargin': killRingMargin,
    'shrink': shrink.toJson(),
    'centerSlab': centerSlab.toJson(),
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
        other.killRingMargin != killRingMargin ||
        other.shrink != shrink ||
        other.centerSlab != centerSlab) {
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
    killRingMargin,
    shrink,
    centerSlab,
    for (final s in spawnPoints) ...[s.x, s.y],
    ...hammers,
  ]);

  @override
  String toString() =>
      'HammerArenaMap(seed: $mapSeed, radius: $platformRadius, '
      'segments: $platformSegmentCount, hammers: ${hammers.length})';
}
