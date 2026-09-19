import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_countdown.dart';
import 'package:app/design/widgets/ttr_round_banner.dart';
import 'package:flutter/material.dart';

/// ROUND_INTRO phase screen: minigame banner and countdown over the
/// phase-tinted backdrop. No round count display — the match is a
/// single round (GDD § 2).
///
/// Pure renderer: the countdown comes from an injected ticker value
/// (host-owned), never from a local timer.
class RoundIntroScreen extends StatelessWidget {
  /// Creates the intro screen.
  const RoundIntroScreen({
    required this.minigameName,
    required this.ruleLine,
    required this.countdownValue,
    super.key,
  });

  /// Key of the countdown text (for tests and integration finds).
  static const Key countdownKey = Key('round_intro_countdown');

  /// Display name of the upcoming minigame.
  final String minigameName;

  /// One-line rule of the upcoming minigame.
  final String ruleLine;

  /// Current countdown value (seconds remaining), injected.
  final int countdownValue;

  @override
  Widget build(BuildContext context) {
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
