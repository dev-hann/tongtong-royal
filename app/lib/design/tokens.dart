/// Design tokens for TongTong Royal — bright, casual, Fall-Guys-style.
///
/// THE single source of truth for colors, type, spacing, radii and
/// motion (conventions doc § 2). No inline `Color(0x...)`, no
/// hand-rolled text styles outside `design/`.
///
/// Purity: this library imports only `dart:ui` colors, so painters
/// (`game/view`) consume it without any Flutter widget dependency.
/// Everything that needs a `BuildContext` or Flutter widgets lives
/// in `design/theme.dart` / `design/widgets/` / `design/game_hud/`.
library;

import 'dart:ui' show Color;

/// Core UI palette: warm orange primary, teal secondary, light
/// background, semantic colors for success/danger/warning.
abstract final class ColorPalette {
  /// Brand primary (warm orange) — buttons, accents, local player.
  static const Color primary = Color(0xFFFF8C42);

  /// Text/icons on [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Brand secondary (teal/cyan) — secondary actions, highlights.
  static const Color secondary = Color(0xFF2EC4B6);

  /// Text/icons on [secondary].
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// App scaffold background (light, casual).
  static const Color background = Color(0xFFF7F9FC);

  /// Card/sheet surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Default text/icon color on background and surface.
  static const Color onSurface = Color(0xFF1B2631);

  /// Neutral scale stop 50 — faint fills, dividers.
  static const Color neutral50 = Color(0xFFF1F4F9);

  /// Neutral scale stop 200 — disabled fills, outlines.
  static const Color neutral200 = Color(0xFFC9D2E0);

  /// Neutral scale stop 500 — secondary text, muted icons.
  static const Color neutral500 = Color(0xFF8D99AE);

  /// Neutral scale stop 700 — strong outlines.
  static const Color neutral700 = Color(0xFF4A5A70);

  /// Neutral scale stop 900 — headings, dark chrome.
  static const Color neutral900 = Color(0xFF1B2631);

  /// Semantic success.
  static const Color success = Color(0xFF3ECF6E);

  /// Semantic danger.
  static const Color danger = Color(0xFFFF4D6D);

  /// Semantic warning (also the gold used by finish/crown zones).
  static const Color warning = Color(0xFFFFD166);

  /// Translucent primary tint (~10% opacity) — ambient backdrop
  /// shapes, phase-tinted washes behind intro/results screens.
  static const Color primarySoft = Color(0x1AFF8C42);

  /// Translucent secondary tint (~10% opacity) — ambient backdrop.
  static const Color secondarySoft = Color(0x1A2EC4B6);

  /// Translucent warning/gold tint (~10% opacity) — ambient backdrop.
  static const Color warningSoft = Color(0x1AFFD166);
}

/// The four player colors. Assigned by seat index (human and bot
/// alike — the BOT badge distinguishes bots, never the color).
abstract final class PlayerPalette {
  /// Seat color 1 — vivid orange.
  static const Color one = Color(0xFFFF8C42);

  /// Seat color 2 — cyan.
  static const Color two = Color(0xFF4CD9E0);

  /// Seat color 3 — pink.
  static const Color three = Color(0xFFFF6FA5);

  /// Seat color 4 — lime.
  static const Color four = Color(0xFFB4E33D);

  /// All seat colors, seat order.
  static const List<Color> all = [one, two, three, four];

  /// Ring/highlight drawn around the local player's body.
  static const Color localRing = Color(0xFFFFFFFF);

  /// Translucent halo painted over the local player's color.
  static const Color localHalo = Color(0x33FFFFFF);

  /// Seat color for [index]; cycles every 4 seats.
  static Color forIndex(int index) => all[index % all.length];
}

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

/// Type scale: sizes (logical px) and weights only — Flutter-side
/// code turns these into `TextStyle`s (see `design/theme.dart`).
abstract final class TypeScale {
  /// Display (countdown numbers, podium ranks): big and loud.
  static const double displaySize = 64;

  /// Display weight.
  static const int displayWeight = 800;

  /// Screen/card titles (minigame names).
  static const double titleSize = 28;

  /// Title weight.
  static const int titleWeight = 700;

  /// Body copy (rules, messages).
  static const double bodySize = 16;

  /// Body weight.
  static const int bodyWeight = 400;

  /// Labels, buttons, badges.
  static const double labelSize = 14;

  /// Label weight.
  static const int labelWeight = 600;
}

/// 4-based spacing scale (logical px).
abstract final class SpacingScale {
  /// 4 — hairline gaps, chip innards.
  static const double xs = 4;

  /// 8 — compact padding.
  static const double sm = 8;

  /// 12 — default control padding.
  static const double md = 12;

  /// 16 — card padding.
  static const double lg = 16;

  /// 24 — between sections.
  static const double xl = 24;

  /// 32 — screen margins.
  static const double xxl = 32;

  /// 48 — major separations.
  static const double xxxl = 48;
}

/// Corner radius scale (logical px).
abstract final class RadiusScale {
  /// Chips and badges.
  static const double chip = 8;

  /// Buttons.
  static const double button = 12;

  /// Cards and banners.
  static const double card = 16;

  /// Fully rounded (stadium) — use with huge values.
  static const double pill = 999;
}

/// Motion durations (milliseconds).
abstract final class MotionDurations {
  /// Button press feedback.
  static const Duration tap = Duration(milliseconds: 80);

  /// Screen/section transitions.
  static const Duration transition = Duration(milliseconds: 240);

  /// Countdown number pop-in.
  static const Duration countdownPop = Duration(milliseconds: 150);

  /// Repeating celebration pulse (podium first-place pedestal).
  static const Duration pulse = Duration(milliseconds: 900);

  /// One slow drift cycle of ambient backdrop shapes.
  static const Duration ambient = Duration(seconds: 12);
}
