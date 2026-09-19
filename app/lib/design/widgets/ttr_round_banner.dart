import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Round banner: minigame display name plus its one-line rule.
class TtrRoundBanner extends StatelessWidget {
  /// Creates the round banner.
  const TtrRoundBanner({
    required this.title,
    required this.ruleLine,
    super.key,
  });

  /// Minigame display name.
  final String title;

  /// One-line rule of the minigame.
  final String ruleLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingScale.lg),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.card),
        border: Border.all(color: ColorPalette.neutral200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TypeScale.title),
          const SizedBox(height: SpacingScale.xs),
          Text(ruleLine, style: TypeScale.body),
        ],
      ),
    );
  }
}
