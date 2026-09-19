/// Design tokens for TongTong Royal — bright, casual, Fall-Guys-style.
///
/// THE single source of truth for colors, type, spacing, radii and
/// motion (conventions doc § 2). No inline `Color(0x...)`, no
/// hand-rolled text styles outside `design/`.
///
/// Purity: this library imports only `dart:ui` colors plus the
/// Flutter `TextStyle` value type, so painters (`game/view`) consume
/// it without any Flutter widget dependency. Everything that needs a
/// `BuildContext` or Flutter widgets lives in `design/theme.dart` /
/// `design/widgets/` / `design/game_hud/`.
library;

import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show FontWeight, TextStyle;

export 'package:app/design/arena_palette.dart' show ArenaPalette;
export 'package:app/design/component_sizes.dart' show ComponentSizes;

/// Font families per design guide § 2. Bundled as variable `.ttf`
/// assets (offline-first); Korean text falls back through
/// [hangulFallback].
abstract final class FontTokens {
  /// Display face — logo, countdown numerals, podium ranks, score
  /// numbers, button labels, badges.
  static const String display = 'Fredoka';

  /// Body face — rule one-liners, player names, lists, standings,
  /// toasts, helper text.
  static const String body = 'Nunito';

  /// Hangul fallback chain: neither bundled face covers Korean, so
  /// every role style and theme slot carries this chain.
  static const List<String> hangulFallback = ['Noto Sans KR', 'sans-serif'];
}

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

  /// Seat color for [seat] when the local human holds palette index
  /// [localIndex] on seat 0 (GDD § 8.1 persisted profile color): the
  /// human keeps the chosen color; the other seats take the
  /// remaining palette colors in order, so no two seats collide.
  static Color forSeat(int seat, {int localIndex = 0}) {
    final local = localIndex % all.length;
    if (seat == 0) {
      return all[local];
    }
    final k = seat - 1;
    return all[(k >= local ? k + 1 : k) % all.length];
  }
}

/// Type scale (guide § 2): per-role [TextStyle]s carrying the role's
/// font family, weight and tracking. Callers own the content side
/// (labels arrive UPPERCASE) and may `copyWith` a color; every other
/// property is a token.
abstract final class TypeScale {
  /// Display size (countdown numbers, logo).
  static const double displaySize = 64;

  /// Medium display size.
  static const double displayMediumSize = 48;

  /// Small display size.
  static const double displaySmallSize = 40;

  /// Screen/card titles (minigame names).
  static const double titleSize = 28;

  /// Headline size (section headers, HUD numerals).
  static const double headlineSize = 24;

  /// Large body size.
  static const double bodyLargeSize = 18;

  /// Body copy (rules, messages).
  static const double bodySize = 16;

  /// Labels, buttons, badges.
  static const double labelSize = 14;

  /// Small labels (compact chips).
  static const double labelSmallSize = 12;

  /// Large button label size.
  static const double buttonLargeSize = 20;

  /// Display weight (logo, big headings).
  static const int displayWeight = 700;

  /// Numeral weight — Fredoka SemiBold (guide § 2: HUD/podium
  /// numbers are always display-face SemiBold, never body-face).
  static const int numeralWeight = 600;

  /// Label weight.
  static const int labelWeight = 600;

  /// Letter spacing for uppercase labels: ~0.057em at 14px — wide
  /// enough to read as deliberate tracking on the rounded display
  /// face without scattering two-letter button verbs.
  static const double labelTracking = 0.8;

  /// Logo / hero display: Fredoka Bold.
  static const TextStyle display = TextStyle(
    fontFamily: FontTokens.display,
    fontSize: displaySize,
    fontWeight: FontWeight.w700,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Countdown / big numerals: Fredoka SemiBold (guide § 2).
  static const TextStyle displayNumeral = TextStyle(
    fontFamily: FontTokens.display,
    fontSize: displaySize,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Screen/card titles and rank labels: Fredoka SemiBold.
  static const TextStyle title = TextStyle(
    fontFamily: FontTokens.display,
    fontSize: titleSize,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Button/badge labels: Fredoka SemiBold, tracked. Content-side
  /// rule: the caller passes the text already UPPERCASE.
  static const TextStyle label = TextStyle(
    fontFamily: FontTokens.display,
    fontSize: labelSize,
    fontWeight: FontWeight.w600,
    letterSpacing: labelTracking,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Large button labels (lobby primary actions).
  static const TextStyle labelLarge = TextStyle(
    fontFamily: FontTokens.display,
    fontSize: buttonLargeSize,
    fontWeight: FontWeight.w600,
    letterSpacing: labelTracking,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Body copy: Nunito Regular.
  static const TextStyle body = TextStyle(
    fontFamily: FontTokens.body,
    fontSize: bodySize,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Emphasized body (player names on cards): Nunito Bold.
  static const TextStyle bodyEmphasis = TextStyle(
    fontFamily: FontTokens.body,
    fontSize: bodySize,
    fontWeight: FontWeight.w700,
    fontFamilyFallback: FontTokens.hangulFallback,
  );

  /// Status/helper labels in the body face: Nunito SemiBold,
  /// tracked ("Ready", "Not ready", helper chips).
  static const TextStyle bodyLabel = TextStyle(
    fontFamily: FontTokens.body,
    fontSize: labelSize,
    fontWeight: FontWeight.w600,
    letterSpacing: labelTracking,
    fontFamilyFallback: FontTokens.hangulFallback,
  );
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

/// Motion durations (milliseconds, guide § 4).
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

  /// Staggered entrance: per-item slide+fade run.
  static const Duration staggerItem = Duration(milliseconds: 240);

  /// Staggered entrance: gap between consecutive items.
  static const Duration staggerDelay = Duration(milliseconds: 40);

  /// Staggered entrance: wait after build before the first item.
  static const Duration staggerStart = Duration(milliseconds: 80);
}

/// Motion scale peaks (guide § 4).
abstract final class MotionScales {
  /// Button press-down squash factor.
  static const double press = 0.96;

  /// Pop-on-change peak (scores, timers, countdowns).
  static const double pop = 1.15;

  /// Emphasis pulse peak (one element per screen).
  static const double pulse = 1.04;
}
