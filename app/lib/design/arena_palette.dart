import 'dart:ui' show Color;

import 'package:app/design/tokens.dart';

export 'package:app/design/tokens.dart' show ColorPalette, PlayerPalette;

/// Arena render colors. Instantiable so painters/tests can override
/// individual colors; every default is a token value, never inline
/// at the call site.
///
/// Player contrast: all [PlayerPalette.all] colors differ from
/// [platform] and [background] by a relative-luminance gap large
/// enough for gameplay legibility (guarded by `design` tests).
class ArenaPalette {
  /// Creates an arena palette; every field defaults to the token.
  const ArenaPalette({
    this.background = const Color(0xFF101820),
    this.platform = const Color(0xFF3E5C76),
    this.platformEdge = const Color(0xFF2C3E50),
    this.hazard = const Color(0xFFE63946),
    this.killZoneHint = const Color(0xFF7A1F2B),
    this.checkpoint = const Color(0xFF7FC8A9),
    this.finishLine = ColorPalette.warning,
    this.playerLocal = PlayerPalette.one,
    this.playerRemote = PlayerPalette.two,
  });

  /// Arena backdrop (behind all geometry).
  final Color background;

  /// Standable platforms/floors.
  final Color platform;

  /// Walls and ramps (darker than [platform]).
  final Color platformEdge;

  /// Hazards (hammer arms and other danger geometry).
  final Color hazard;

  /// Kill zone hint (fall line, kill ring).
  final Color killZoneHint;

  /// Checkpoint markers.
  final Color checkpoint;

  /// Finish line sensor.
  final Color finishLine;

  /// Local player body.
  final Color playerLocal;

  /// Remote player bodies.
  final Color playerRemote;
}
