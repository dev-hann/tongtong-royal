import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_countdown.dart';
import 'package:app/design/widgets/ttr_round_banner.dart';
import 'package:flutter/material.dart';

/// SHOW_INTRO phase screen (GDD v2 § 5, FOCUSED archetype): ROUND
/// n / 3 pill, game banner (name + rule line + verb chip) and the
/// giant countdown over the game-tinted backdrop.
///
/// Pure renderer: the countdown comes from the injected ticker value
/// (controller-owned), never from a local timer. System back opens
/// the quit confirm (GDD v2 § 7.4 — abandoning the show records
/// nothing) via [onQuitAttempt].
class ShowIntroScreen extends StatelessWidget {
  /// Creates the intro screen.
  const ShowIntroScreen({
    required this.roundNumber,
    required this.totalRounds,
    required this.gameName,
    required this.ruleLine,
    required this.verb,
    required this.countdownValue,
    this.isFinal = false,
    this.onQuitAttempt,
    super.key,
  });

  /// Key of the round pill (tests and integration finds).
  static const Key roundPillKey = Key('show_intro_round_pill');

  /// 1-based round number for the pill.
  final int roundNumber;

  /// Total rounds in the show (GDD v2 § 1: 3).
  final int totalRounds;

  /// Display name of the upcoming game.
  final String gameName;

  /// One-line rule of the upcoming game.
  final String ruleLine;

  /// The game's one-button verb (GDD v2 § 3), e.g. `JUMP`.
  final String verb;

  /// Current countdown value (seconds remaining), injected.
  final int countdownValue;

  /// Whether this intro opens the FINAL (crown round).
  final bool isFinal;

  /// Invoked when system back fires during the intro: the shell
  /// runs the quit confirm dialog (GDD v2 § 7.4).
  final VoidCallback? onQuitAttempt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onQuitAttempt?.call();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TtrAmbientBackdrop(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  if (isFinal)
                    ColorPalette.warningSoft
                  else
                    ColorPalette.primarySoft,
                  ColorPalette.background,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundPill(
                      key: roundPillKey,
                      text: 'ROUND $roundNumber / $totalRounds',
                      emphasized: isFinal,
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    TtrRoundBanner(title: gameName, ruleLine: ruleLine),
                    const SizedBox(height: SpacingScale.md),
                    _VerbChip(verb: verb),
                    const SizedBox(height: SpacingScale.xl),
                    TtrCountdown(value: countdownValue),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.text, required this.emphasized, super.key});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? ColorPalette.warning : ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        border: Border.all(
          color: emphasized ? ColorPalette.warning : ColorPalette.neutral200,
        ),
      ),
      child: Text(
        text,
        style: TypeScale.label.copyWith(
          color: emphasized ? ColorPalette.neutral900 : ColorPalette.onSurface,
        ),
      ),
    );
  }
}

/// The single-button affordance preview: verb chip in the display
/// face (GDD v2 § 3 — one button per game, each game its own verb).
class _VerbChip extends StatelessWidget {
  const _VerbChip({required this.verb});

  final String verb;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.secondary,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
      ),
      child: Text(
        verb,
        style: TypeScale.labelLarge.copyWith(color: ColorPalette.onSecondary),
      ),
    );
  }
}
