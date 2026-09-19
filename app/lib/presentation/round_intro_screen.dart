import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_countdown.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:app/design/widgets/ttr_round_banner.dart';
import 'package:flutter/material.dart';

/// ROUND_INTRO phase screen: round badge, minigame banner, countdown,
/// phase-tinted backdrop.
///
/// Pure renderer: the countdown comes from an injected ticker value
/// (host-owned), never from a local timer. The round badge is the
/// screen's single pulsing element (guide § 4).
class RoundIntroScreen extends StatelessWidget {
  /// Creates the intro screen.
  const RoundIntroScreen({
    required this.minigameName,
    required this.ruleLine,
    required this.countdownValue,
    this.roundNumber,
    this.totalRounds,
    super.key,
  });

  /// Key of the round badge pill (for tests and integration finds).
  static const Key roundBadgeKey = Key('round_intro_badge');

  /// Key of the countdown text (for tests and integration finds).
  static const Key countdownKey = Key('round_intro_countdown');

  /// Display name of the upcoming minigame.
  final String minigameName;

  /// One-line rule of the upcoming minigame.
  final String ruleLine;

  /// Current countdown value (seconds remaining), injected.
  final int countdownValue;

  /// 1-based round number; `null` hides the badge pill.
  final int? roundNumber;

  /// Total rounds in the match, injected.
  final int? totalRounds;

  @override
  Widget build(BuildContext context) {
    final round = roundNumber;
    return Stack(
      fit: StackFit.expand,
      children: [
        const TtrAmbientBackdrop(),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [ColorPalette.primarySoft, ColorPalette.background],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (round != null)
                    TtrPulse(
                      child: _RoundBadge(
                        label: 'ROUND $round / ${totalRounds ?? round}',
                      ),
                    ),
                  const SizedBox(height: SpacingScale.lg),
                  TtrRoundBanner(title: minigameName, ruleLine: ruleLine),
                  const SizedBox(height: SpacingScale.xl),
                  TtrCountdown(key: countdownKey, value: countdownValue),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: RoundIntroScreen.roundBadgeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.secondary,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
      ),
      child: Text(
        label,
        style: TypeScale.label.copyWith(
          color: ColorPalette.onSecondary,
        ),
      ),
    );
  }
}
