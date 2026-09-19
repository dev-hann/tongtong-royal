import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Builds the TongTong Royal Material 3 theme.
///
/// Derived ONLY from `design/tokens.dart` (conventions doc § 2):
/// no hand-rolled colors, sizes or durations appear here. Every text
/// slot maps to a guide § 2 family — display-side slots (screens,
/// headlines, titles, buttons) Fredoka, body-side slots Nunito — and
/// carries the Hangul fallback chain via the token styles.
ThemeData buildTtrTheme() {
  const scheme = ColorScheme.light(
    primary: ColorPalette.primary,
    secondary: ColorPalette.secondary,
    tertiary: ColorPalette.warning,
    onTertiary: ColorPalette.onSurface,
    error: ColorPalette.danger,
    onSurface: ColorPalette.onSurface,
  );

  final textTheme = TextTheme(
    displayLarge: TypeScale.display,
    displayMedium: TypeScale.display.copyWith(
      fontSize: TypeScale.displayMediumSize,
    ),
    displaySmall: TypeScale.display.copyWith(
      fontSize: TypeScale.displaySmallSize,
    ),
    headlineLarge: TypeScale.title.copyWith(
      fontSize: TypeScale.headlineSize,
    ),
    headlineMedium: TypeScale.title,
    headlineSmall: TypeScale.title.copyWith(
      fontSize: TypeScale.headlineSize,
    ),
    titleLarge: TypeScale.title,
    titleMedium: TypeScale.title.copyWith(
      fontSize: TypeScale.bodyLargeSize,
    ),
    titleSmall: TypeScale.label,
    bodyLarge: TypeScale.body.copyWith(
      fontSize: TypeScale.bodyLargeSize,
    ),
    bodyMedium: TypeScale.body,
    bodySmall: TypeScale.body.copyWith(
      fontSize: TypeScale.labelSize,
    ),
    labelLarge: TypeScale.label,
    labelMedium: TypeScale.bodyLabel,
    labelSmall: TypeScale.bodyLabel.copyWith(
      fontSize: TypeScale.labelSmallSize,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ColorPalette.background,
    textTheme: textTheme,
    fontFamilyFallback: FontTokens.hangulFallback,
  );
}
