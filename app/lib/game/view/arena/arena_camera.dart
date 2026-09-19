import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Engine constant: camera padding beyond the hammer kill ring,
/// meters, so the kill rim stays visible inside the view.
/// Display-only.
const double hammerCameraPaddingMeters = 0.5;

/// Immutable world-space rectangle the arena camera is clamped to,
/// derived from arena map data only (never from Forge2D bodies).
@immutable
final class ArenaCameraBounds {
  /// Creates bounds from raw extents.
  const ArenaCameraBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  /// Computes the camera bounds of a Hammer Dodge arena: a square
  /// centered on the platform pivot (map origin) whose sides sit
  /// [hammerCameraPaddingMeters] beyond the kill ring. Everything
  /// standable or lethal lives inside that square.
  factory ArenaCameraBounds.fromHammerMap(HammerArenaMap map) {
    final extent = map.killRadius + hammerCameraPaddingMeters;
    return ArenaCameraBounds(
      minX: -extent,
      maxX: extent,
      minY: -extent,
      maxY: extent,
    );
  }

  /// Left edge, meters.
  final double minX;

  /// Right edge, meters.
  final double maxX;

  /// Bottom edge, meters (kill floor line).
  final double minY;

  /// Top edge, meters.
  final double maxY;
}
