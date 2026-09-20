import 'package:app/design/game_art/jelly_primitives.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests per jelly state (docs/03 § 6: goldens for critical
/// visuals only — the jelly character is the show's primary art
/// asset, guide § 9.1). Baselines were generated once with
/// `flutter test --update-goldens`; from then on changes are
/// intentional diffs.
void main() {
  Widget harness(JellyCharacterPainter painter) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      child: ColoredBox(
        color: ColorPalette.background,
        child: Center(
          child: CustomPaint(size: const Size(120, 120), painter: painter),
        ),
      ),
    ),
  );

  testWidgets('golden: idle breathing jelly', (tester) async {
    await tester.pumpWidget(
      harness(const JellyCharacterPainter(body: PlayerPalette.two)),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_idle.png'),
    );
  });

  testWidgets('golden: jump squash jelly', (tester) async {
    await tester.pumpWidget(
      harness(
        const JellyCharacterPainter(
          body: PlayerPalette.two,
          pose: JellyPose.jump,
        ),
      ),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_jump.png'),
    );
  });

  testWidgets('golden: land bounce jelly', (tester) async {
    await tester.pumpWidget(
      harness(
        const JellyCharacterPainter(
          body: PlayerPalette.two,
          pose: JellyPose.land,
          phase: 0.5,
        ),
      ),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_land.png'),
    );
  });

  testWidgets('golden: eliminated spinning jelly', (tester) async {
    await tester.pumpWidget(
      harness(
        const JellyCharacterPainter(
          body: PlayerPalette.two,
          pose: JellyPose.eliminated,
          phase: 0.25,
        ),
      ),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_eliminated.png'),
    );
  });

  testWidgets('golden: blinking jelly', (tester) async {
    await tester.pumpWidget(
      harness(
        const JellyCharacterPainter(body: PlayerPalette.two, blink: true),
      ),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_blink.png'),
    );
  });

  testWidgets('golden: local player ring jelly', (tester) async {
    await tester.pumpWidget(
      harness(
        const JellyCharacterPainter(body: PlayerPalette.one, isLocal: true),
      ),
    );
    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/jelly_local_ring.png'),
    );
  });
}
