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
  });
}
