import 'package:app/design/theme.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds a Material 3 theme from tokens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTtrTheme(), home: const SizedBox()),
    );

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, ColorPalette.primary);
    expect(theme.colorScheme.secondary, ColorPalette.secondary);
    expect(theme.colorScheme.error, ColorPalette.danger);
    expect(theme.scaffoldBackgroundColor, ColorPalette.background);
  });

  testWidgets('maps every text slot to the guide § 2 role families', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTtrTheme(), home: const SizedBox()),
    );

    final text = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
        .textTheme;

    // Display-side slots: Fredoka.
    for (final style in [
      text.displayLarge,
      text.displayMedium,
      text.displaySmall,
      text.headlineLarge,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
    ]) {
      expect(style!.fontFamily, FontTokens.display, reason: '$style');
    }

    // Body-side slots: Nunito.
    for (final style in [
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style!.fontFamily, FontTokens.body, reason: '$style');
    }

    // Buttons (labelLarge) carry the display face per guide § 2.
    expect(text.labelLarge!.fontFamily, FontTokens.display);
  });

  testWidgets('every text slot carries the Hangul fallback chain', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTtrTheme(), home: const SizedBox()),
    );

    final text = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
        .textTheme;
    final styles = [
      text.displayLarge,
      text.displayMedium,
      text.displaySmall,
      text.headlineLarge,
      text.headlineMedium,
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ];
    for (final style in styles) {
      expect(style!.fontFamilyFallback, FontTokens.hangulFallback);
    }
  });

  testWidgets('text theme maps token sizes and weights', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTtrTheme(), home: const SizedBox()),
    );

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme.textTheme.displayLarge!.fontSize, TypeScale.displaySize);
    expect(
      theme.textTheme.displayLarge!.fontWeight!.value,
      TypeScale.displayWeight,
    );
    expect(theme.textTheme.bodyMedium!.fontSize, TypeScale.bodySize);
    expect(
      theme.textTheme.labelLarge!.fontWeight!.value,
      TypeScale.labelWeight,
    );
    expect(
      theme.textTheme.labelLarge!.letterSpacing,
      TypeScale.labelTracking,
    );
  });
}
