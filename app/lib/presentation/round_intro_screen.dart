import 'package:flutter/material.dart';

/// ROUND_INTRO phase screen: minigame name, one-line rule, countdown.
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(minigameName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(ruleLine),
        const SizedBox(height: 24),
        Text(
          '$countdownValue',
          key: countdownKey,
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ],
    );
  }
}
