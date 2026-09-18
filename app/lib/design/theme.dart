import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Builds the TongTong Royal Material 3 theme.
///
/// Derived ONLY from `design/tokens.dart` (conventions doc § 2):
/// no hand-rolled colors, sizes or durations appear here.
ThemeData buildTtrTheme() {
  const scheme = ColorScheme.light(
    primary: ColorPalette.primary,
    secondary: ColorPalette.secondary,
    tertiary: ColorPalette.warning,
    onTertiary: ColorPalette.onSurface,
    error: ColorPalette.danger,
    onSurface: ColorPalette.onSurface,
  );

  const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: TypeScale.displaySize,
      fontWeight: FontWeight.w800,
      color: ColorPalette.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: TypeScale.titleSize,
      fontWeight: FontWeight.w700,
      color: ColorPalette.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: TypeScale.titleSize,
      fontWeight: FontWeight.w700,
      color: ColorPalette.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: TypeScale.bodySize,
      fontWeight: FontWeight.w400,
      color: ColorPalette.onSurface,
    ),
    labelLarge: TextStyle(
      fontSize: TypeScale.labelSize,
      fontWeight: FontWeight.w600,
      color: ColorPalette.onSurface,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ColorPalette.background,
    textTheme: textTheme,
  );
}
