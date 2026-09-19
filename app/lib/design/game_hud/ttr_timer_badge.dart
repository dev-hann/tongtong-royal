import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_pop_on_change.dart';
import 'package:flutter/material.dart';

/// HUD timer badge: pill with the host-owned remaining time.
///
/// Numerals render in the Fredoka SemiBold display role (guide § 2)
/// and pop on every second change (guide § 4).
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
      child: TtrPopOnChange(
        tag: timeLabel,
        child: Text(timeLabel, style: TypeScale.title),
      ),
    );
  }
}
