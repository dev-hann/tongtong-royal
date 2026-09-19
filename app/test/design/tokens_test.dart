import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:app/design/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance of [color].
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

void main() {
  group('PlayerPalette', () {
    test('has exactly 4 distinct seat colors', () {
      expect(PlayerPalette.all, hasLength(4));
      expect(PlayerPalette.all.toSet(), hasLength(4));
    });

    test('forIndex cycles every 4 seats', () {
      expect(PlayerPalette.forIndex(0), PlayerPalette.one);
      expect(PlayerPalette.forIndex(4), PlayerPalette.one);
      expect(PlayerPalette.forIndex(5), PlayerPalette.two);
    });

    test('forSeat gives seat 0 the chosen local color', () {
      expect(PlayerPalette.forSeat(0, localIndex: 2), PlayerPalette.three);
      expect(PlayerPalette.forSeat(0), PlayerPalette.one);
    });

    test('forSeat never collides with the local color', () {
      for (var local = 0; local < PlayerPalette.all.length; local++) {
        final used = <Color>{PlayerPalette.forSeat(0, localIndex: local)};
        for (var seat = 1; seat < PlayerPalette.all.length; seat++) {
          final color = PlayerPalette.forSeat(seat, localIndex: local);
          expect(
            color,
            isNot(used.contains(color)),
            reason: 'local $local, seat $seat',
          );
          used.add(color);
        }
      }
    });

    test('every seat color contrasts with arena platform and background', () {
      const arena = ArenaPalette();
      for (final player in PlayerPalette.all) {
        final playerLuminance = relativeLuminance(player);
        expect(
          (playerLuminance - relativeLuminance(arena.platform)).abs(),
          greaterThan(0.25),
          reason: 'seat $player vs platform',
        );
        expect(
          (playerLuminance - relativeLuminance(arena.background)).abs(),
          greaterThan(0.25),
          reason: 'seat $player vs background',
        );
      }
    });
  });

  group('ArenaPalette', () {
    test('default palette derives player colors from PlayerPalette', () {
      const arena = ArenaPalette();
      expect(arena.playerLocal, PlayerPalette.one);
      expect(arena.playerRemote, PlayerPalette.two);
    });

    test('individual colors can be overridden for tests', () {
      const arena = ArenaPalette(hazard: ColorPalette.danger);
      expect(arena.hazard, ColorPalette.danger);
      expect(arena.platform, const ArenaPalette().platform);
    });
  });

  group('ColorPalette', () {
    test('exposes a 5-stop neutral scale', () {
      const stops = [
        ColorPalette.neutral50,
        ColorPalette.neutral200,
        ColorPalette.neutral500,
        ColorPalette.neutral700,
        ColorPalette.neutral900,
      ];
      expect(stops.toSet(), hasLength(5));
    });
  });

  group('scales', () {
    test('spacing scale is 4-based', () {
      const values = [
        SpacingScale.xs,
        SpacingScale.sm,
        SpacingScale.md,
        SpacingScale.lg,
        SpacingScale.xl,
        SpacingScale.xxl,
        SpacingScale.xxxl,
      ];
      final multipleOf4 = predicate<double>((v) => v % 4 == 0, 'multiple of 4');
      expect(values, everyElement(multipleOf4));
      expect(values.toSet(), hasLength(7));
    });

    test('motion durations match the spec', () {
      expect(MotionDurations.tap, const Duration(milliseconds: 80));
      expect(MotionDurations.transition, const Duration(milliseconds: 240));
      expect(MotionDurations.countdownPop, const Duration(milliseconds: 150));
      expect(MotionDurations.pulse, const Duration(milliseconds: 900));
      expect(MotionDurations.ambient, const Duration(seconds: 12));
    });

    test('staggered-entrance durations match guide § 4', () {
      expect(MotionDurations.staggerItem, const Duration(milliseconds: 240));
      expect(MotionDurations.staggerDelay, const Duration(milliseconds: 40));
      expect(MotionDurations.staggerStart, const Duration(milliseconds: 80));
    });
  });

  group('component sizes', () {
    test('avatar circle diameter is 96 (guide § 6 tokenized avatar)', () {
      expect(ComponentSizes.avatar, 96);
    });
  });

  group('motion scales', () {
    test('press/pop/pulse peaks match guide § 4', () {
      expect(MotionScales.press, 0.96);
      expect(MotionScales.pop, 1.15);
      expect(MotionScales.pulse, 1.04);
    });
  });

  group('typography', () {
    test('FontTokens assign the two bundled families per guide § 2', () {
      expect(FontTokens.display, 'Fredoka');
      expect(FontTokens.body, 'Nunito');
    });

    test('Hangul fallback chain is declared once', () {
      expect(FontTokens.hangulFallback, ['Noto Sans KR', 'sans-serif']);
    });

    test('label tracking is a positive wide-ish value', () {
      expect(TypeScale.labelTracking, greaterThan(0));
    });

    test('display roles use the display family with tracking-free text', () {
      expect(TypeScale.display.fontFamily, FontTokens.display);
      expect(TypeScale.displayNumeral.fontFamily, FontTokens.display);
      expect(TypeScale.displayNumeral.fontWeight!.value, 600);
      expect(TypeScale.display.letterSpacing, isNull);
    });

    test('label roles use the display family plus label tracking', () {
      expect(TypeScale.label.fontFamily, FontTokens.display);
      expect(TypeScale.label.fontWeight!.value, 600);
      expect(TypeScale.label.letterSpacing, TypeScale.labelTracking);
      expect(TypeScale.labelLarge.letterSpacing, TypeScale.labelTracking);
    });

    test('body roles use the body family', () {
      expect(TypeScale.body.fontFamily, FontTokens.body);
      expect(TypeScale.bodyEmphasis.fontFamily, FontTokens.body);
      expect(TypeScale.bodyLabel.fontFamily, FontTokens.body);
      expect(TypeScale.bodyLabel.letterSpacing, TypeScale.labelTracking);
    });

    test('every role carries the Hangul fallback chain', () {
      const roles = [
        TypeScale.display,
        TypeScale.displayNumeral,
        TypeScale.title,
        TypeScale.label,
        TypeScale.labelLarge,
        TypeScale.body,
        TypeScale.bodyEmphasis,
        TypeScale.bodyLabel,
      ];
      for (final role in roles) {
        expect(role.fontFamilyFallback, FontTokens.hangulFallback);
      }
    });
  });

  group('backdrop tints', () {
    int alpha255(Color color) => (color.a * 255).round();

    test('soft tints are translucent variants of brand colors', () {
      expect(alpha255(ColorPalette.primarySoft), 0x1A);
      expect(alpha255(ColorPalette.secondarySoft), 0x1A);
      expect(alpha255(ColorPalette.warningSoft), 0x1A);
      expect(
        ColorPalette.primarySoft.withValues(alpha: 1),
        ColorPalette.primary,
      );
      expect(
        ColorPalette.secondarySoft.withValues(alpha: 1),
        ColorPalette.secondary,
      );
      expect(
        ColorPalette.warningSoft.withValues(alpha: 1),
        ColorPalette.warning,
      );
    });
  });
}
