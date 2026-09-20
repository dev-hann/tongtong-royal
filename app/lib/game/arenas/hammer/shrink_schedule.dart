import 'package:flutter/foundation.dart' show immutable;

/// Shrink-phase schedule of a survival arena (hammer-dodge.md § Level
/// design): from [startSeconds] the platform radius shrinks linearly
/// toward [endRadius] over [durationSeconds] seconds; the platform is
/// pre-built at [tierCount] discrete radius tiers whose outer tiers
/// drop as the shrinking rim passes them (map data, not physics
/// tuning).
@immutable
final class ShrinkSchedule {
  /// Creates a schedule shrinking toward [endRadius].
  ShrinkSchedule({
    required this.startSeconds,
    required this.durationSeconds,
    required this.endRadius,
    required this.tierCount,
  }) {
    if (startSeconds < 0 ||
        durationSeconds <= 0 ||
        tierCount < 2 ||
        endRadius <= 0) {
      throw ArgumentError.value(
        this,
        'schedule',
        'invalid shrink schedule values',
      );
    }
  }

  /// Parses the object produced by [toJson]. Throws [FormatException]
  /// on malformed data.
  factory ShrinkSchedule.fromJson(Map<String, Object?> json) {
    Object? field(String name) {
      final value = json[name];
      if (value == null) {
        throw FormatException('ShrinkSchedule.$name is missing');
      }
      return value;
    }

    int count(Object? value, String name) {
      if (value is! int) {
        throw FormatException('ShrinkSchedule.$name must be an integer');
      }
      return value;
    }

    return ShrinkSchedule(
      startSeconds: _asDouble(field('startSeconds'), 'startSeconds'),
      durationSeconds: _asDouble(field('durationSeconds'), 'durationSeconds'),
      endRadius: _asDouble(field('endRadius'), 'endRadius'),
      tierCount: count(field('tierCount'), 'tierCount'),
    );
  }

  /// Seconds of idle arena before the rim starts shrinking.
  final double startSeconds;

  /// Seconds the shrink phase takes.
  final double durationSeconds;

  /// Platform radius the shrink settles at, meters.
  final double endRadius;

  /// Discrete radius tiers the platform is pre-built at; outer tiers
  /// drop as the shrinking rim passes them.
  final int tierCount;

  /// Platform radius at [elapsedSeconds] for an arena starting at
  /// [startRadius]: constant before [startSeconds], linear to
  /// [endRadius] over [durationSeconds], constant after.
  double radiusAt(double startRadius, double elapsedSeconds) {
    if (!elapsedSeconds.isFinite) {
      throw ArgumentError.value(elapsedSeconds, 'elapsedSeconds');
    }
    if (elapsedSeconds <= startSeconds) {
      return startRadius;
    }
    if (elapsedSeconds >= startSeconds + durationSeconds) {
      return endRadius;
    }
    final progress = (elapsedSeconds - startSeconds) / durationSeconds;
    return startRadius + (endRadius - startRadius) * progress;
  }

  /// Tier radii for an arena starting at [startRadius]: [tierCount]
  /// values descending from [startRadius] to [endRadius] in even
  /// steps. The outermost tier equals the pre-shrink platform; the
  /// innermost equals the settled platform and never drops.
  List<double> tierRadii(double startRadius) {
    if (startRadius <= endRadius) {
      throw ArgumentError.value(
        startRadius,
        'startRadius',
        'must exceed the schedule endRadius',
      );
    }
    final step = (startRadius - endRadius) / (tierCount - 1);
    return [
      for (var i = 0; i < tierCount; i++) startRadius - step * i,
    ];
  }

  /// JSON: every field.
  Map<String, Object?> toJson() => <String, Object?>{
    'startSeconds': startSeconds,
    'durationSeconds': durationSeconds,
    'endRadius': endRadius,
    'tierCount': tierCount,
  };

  static double _asDouble(Object? value, String field) {
    if (value is! num) {
      throw FormatException('ShrinkSchedule.$field must be a number');
    }
    return value.toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is ShrinkSchedule &&
      other.startSeconds == startSeconds &&
      other.durationSeconds == durationSeconds &&
      other.endRadius == endRadius &&
      other.tierCount == tierCount;

  @override
  int get hashCode =>
      Object.hash(startSeconds, durationSeconds, endRadius, tierCount);

  @override
  String toString() =>
      'ShrinkSchedule(start: ${startSeconds}s, duration: '
      '${durationSeconds}s, end: ${endRadius}m, tiers: $tierCount)';
}
