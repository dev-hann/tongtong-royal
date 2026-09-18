import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// HUD score strip: current round plus cumulative points per
/// player. All values are injected (host-owned, architecture
/// doc § 4).
class TtrScoreStrip extends StatelessWidget {
  /// Creates the score strip.
  const TtrScoreStrip({required this.entries, this.roundNumber, super.key});

  /// Cumulative score entries, injected.
  final List<ScoreEntry> entries;

  /// 1-based round number; `null` hides the round chip.
  final int? roundNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (roundNumber case final round?)
          Padding(
            padding: const EdgeInsets.only(right: SpacingScale.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingScale.sm,
                vertical: SpacingScale.xs,
              ),
              decoration: BoxDecoration(
                color: ColorPalette.secondary,
                borderRadius: BorderRadius.circular(RadiusScale.chip),
              ),
              child: Text(
                'Round $round',
                style: const TextStyle(
                  fontSize: TypeScale.labelSize,
                  fontWeight: FontWeight.w600,
                  color: ColorPalette.onSecondary,
                ),
              ),
            ),
          ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(right: SpacingScale.sm),
            child: Text(
              '${entry.playerId}: ${entry.points}',
              style: const TextStyle(
                fontSize: TypeScale.labelSize,
                fontWeight: FontWeight.w600,
                color: ColorPalette.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
