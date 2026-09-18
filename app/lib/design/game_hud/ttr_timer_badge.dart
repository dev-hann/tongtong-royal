import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// HUD timer badge: pill with the host-owned remaining time.
class TtrTimerBadge extends StatelessWidget {
  /// Creates the timer badge.
  const TtrTimerBadge({required this.timeLabel, super.key});

  /// Remaining-time text, injected from host state.
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        border: Border.all(color: ColorPalette.neutral200),
      ),
      child: Text(
        timeLabel,
        style: const TextStyle(
          fontSize: TypeScale.titleSize,
          fontWeight: FontWeight.w700,
          color: ColorPalette.onSurface,
        ),
      ),
    );
  }
}
