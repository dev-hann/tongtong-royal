import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:forge2d/forge2d.dart';

/// Axis-aligned box in world meters. Map data, not physics tuning
/// (architecture doc § 3): layout numbers describe a course variant
/// and ship as JSON; dynamic behavior constants stay in
/// `PhysicsConsts`.
@immutable
final class BoxSpec {
  /// Creates a box with [center] (its middle point), [width] and
  /// [height] in meters.
  const BoxSpec({
    required this.center,
    required this.width,
    required this.height,
  });

  /// Parses the object produced by [toJson].
  factory BoxSpec.fromJson(Map<String, Object?> json) {
    final center = json['center'];
    if (center is! List || center.length != 2) {
      throw const FormatException('BoxSpec.center must be [x, y]');
    }
    return BoxSpec(
      center: Vector2(
        (center[0] as num).toDouble(),
        (center[1] as num).toDouble(),
      ),
      width: _asDouble(json['width'], 'width'),
      height: _asDouble(json['height'], 'height'),
    );
  }

  /// Center of the box, world coordinates.
  final Vector2 center;

  /// Full extent along x, meters.
  final double width;

  /// Full extent along y, meters.
  final double height;

  /// JSON: `{'center': [x, y], 'width': w, 'height': h}`.
  Map<String, Object?> toJson() => <String, Object?>{
    'center': [center.x, center.y],
    'width': width,
    'height': height,
  };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('BoxSpec.$field must be a number');
    }
    return value.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is BoxSpec &&
      other.center.x == center.x &&
      other.center.y == center.y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(center.x, center.y, width, height);

  @override
  String toString() =>
      'BoxSpec(center: $center, width: $width, height: $height)';
}

/// One rotating hammer (kinematic arm on a revolute-joint pivot).
///
/// Position/radius/speed are seeded map data; [armThickness] and
/// [maxMotorTorque] are part of the serialized variant data too, so
/// no tuning constant leaks into engine code.
@immutable
final class HammerSpec {
  /// Creates a hammer anchored at [pivot], arm starting at
  /// [initialAngle] radians from the +x axis.
  const HammerSpec({
    required this.pivot,
    required this.radius,
    required this.angularSpeed,
    this.initialAngle = defaultInitialAngle,
    this.armThickness = defaultArmThickness,
    this.maxMotorTorque = defaultMaxMotorTorque,
    this.headLength,
  });

  /// Parses the object produced by [toJson].
  factory HammerSpec.fromJson(Map<String, Object?> json) {
    final pivot = json['pivot'];
    if (pivot is! List || pivot.length != 2) {
      throw const FormatException('HammerSpec.pivot must be [x, y]');
    }
    final angularSpeed = json['angularSpeed'];
    if (angularSpeed is! num) {
      throw const FormatException('HammerSpec.angularSpeed must be a number');
    }
    return HammerSpec(
      pivot: Vector2(
        (pivot[0] as num).toDouble(),
        (pivot[1] as num).toDouble(),
      ),
      radius: _asDouble(json['radius'], 'radius'),
      angularSpeed: angularSpeed.toDouble(),
      initialAngle: _asDouble(json['initialAngle'], 'initialAngle'),
      armThickness: _asDouble(json['armThickness'], 'armThickness'),
      maxMotorTorque: _asDouble(json['maxMotorTorque'], 'maxMotorTorque'),
      headLength: json['headLength'] == null
          ? null
          : _asDouble(json['headLength'], 'headLength'),
    );
  }

  /// Default arm cross-section thickness, meters.
  static const double defaultArmThickness = 0.4;

  /// Default motor torque, newton-meters — sized so the motor never
  /// stalls against player bodies.
  static const double defaultMaxMotorTorque = 100000;

  /// Default arm start angle, radians from the +x axis.
  static const double defaultInitialAngle = 0;

  /// Pivot (rotation center), world coordinates.
  final Vector2 pivot;

  /// Arm length from pivot to tip, meters.
  final double radius;

  /// Rotation speed, radians per second.
  final double angularSpeed;

  /// Arm start angle, radians from the +x axis.
  final double initialAngle;

  /// Arm cross-section thickness, meters.
  final double armThickness;

  /// Motor torque of the revolute joint, newton-meters.
  final double maxMotorTorque;

  /// When set, the arm is a banded mallet head spanning
  /// `[radius - headLength, radius]` instead of a full bar
  /// `[0, radius]` — survival-arena arms sweep a radius band
  /// (hammer-dodge.md § Level design), race hammers block a full
  /// column. Serialized as `null` when absent.
  final double? headLength;

  /// JSON: all fields, with the defaulted ones included.
  Map<String, Object?> toJson() => <String, Object?>{
    'pivot': [pivot.x, pivot.y],
    'radius': radius,
    'angularSpeed': angularSpeed,
    'initialAngle': initialAngle,
    'armThickness': armThickness,
    'maxMotorTorque': maxMotorTorque,
    'headLength': headLength,
  };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('HammerSpec.$field must be a number');
    }
    return value.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is HammerSpec &&
      other.pivot.x == pivot.x &&
      other.pivot.y == pivot.y &&
      other.radius == radius &&
      other.angularSpeed == angularSpeed &&
      other.initialAngle == initialAngle &&
      other.armThickness == armThickness &&
      other.maxMotorTorque == maxMotorTorque &&
      other.headLength == headLength;

  @override
  int get hashCode =>
      Object.hash(pivot.x, pivot.y, radius, angularSpeed, initialAngle,
          headLength);

  @override
  String toString() =>
      'HammerSpec(pivot: $pivot, radius: $radius, '
      'angularSpeed: $angularSpeed)';
}

/// One sinusoidally oscillating wall (squeeze gates, trap-race.md §
/// Level design): a kinematic box whose center y follows
/// `base + amplitude * sin(2*pi*t/period + phase)`.
@immutable
final class MovingWallSpec {
  /// Creates a wall spec.
  const MovingWallSpec({
    required this.center,
    required this.width,
    required this.height,
    required this.amplitude,
    required this.period,
    this.phase = 0,
  });

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data.
  factory MovingWallSpec.fromJson(Map<String, Object?> json) {
    final center = json['center'];
    if (center is! List || center.length != 2) {
      throw const FormatException('MovingWallSpec.center must be [x, y]');
    }
    return MovingWallSpec(
      center: Vector2(
        (center[0] as num).toDouble(),
        (center[1] as num).toDouble(),
      ),
      width: _asDouble(json['width'], 'width'),
      height: _asDouble(json['height'], 'height'),
      amplitude: _asDouble(json['amplitude'], 'amplitude'),
      period: _asDouble(json['period'], 'period'),
      phase: _asDouble(json['phase'], 'phase'),
    );
  }

  /// Wall center at oscillation midpoint (x, base y), meters.
  final Vector2 center;

  /// Wall width (x extent), meters.
  final double width;

  /// Wall height (y extent), meters.
  final double height;

  /// Oscillation amplitude, meters.
  final double amplitude;

  /// Oscillation period, seconds.
  final double period;

  /// Oscillation phase offset, radians.
  final double phase;

  /// Wall center y at [seconds] elapsed time.
  double centerYAt(double seconds) =>
      center.y + amplitude * math.sin(2 * math.pi * seconds / period + phase);

  /// JSON: every field; the center serializes as `[x, y]`.
  Map<String, Object?> toJson() => <String, Object?>{
    'center': [center.x, center.y],
    'width': width,
    'height': height,
    'amplitude': amplitude,
    'period': period,
    'phase': phase,
  };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('MovingWallSpec.$field must be a number');
    }
    return value.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is MovingWallSpec &&
      other.center.x == center.x &&
      other.center.y == center.y &&
      other.width == width &&
      other.height == height &&
      other.amplitude == amplitude &&
      other.period == period &&
      other.phase == phase;

  @override
  int get hashCode =>
      Object.hash(center.x, center.y, width, height, amplitude, period, phase);

  @override
  String toString() =>
      'MovingWallSpec(center: $center, amplitude: $amplitude, '
      'period: $period)';
}
