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

  /// JSON: all fields, with the defaulted ones included.
  Map<String, Object?> toJson() => <String, Object?>{
    'pivot': [pivot.x, pivot.y],
    'radius': radius,
    'angularSpeed': angularSpeed,
    'initialAngle': initialAngle,
    'armThickness': armThickness,
    'maxMotorTorque': maxMotorTorque,
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
      other.maxMotorTorque == maxMotorTorque;

  @override
  int get hashCode =>
      Object.hash(pivot.x, pivot.y, radius, angularSpeed, initialAngle);

  @override
  String toString() =>
      'HammerSpec(pivot: $pivot, radius: $radius, '
      'angularSpeed: $angularSpeed)';
}
