import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// HUD score strip: current round plus cumulative points per
/// player. All values are injected (host-owned, architecture
/// doc § 4).
class TtrScoreStrip extends StatelessWidget {
  /// Creates the score strip.
  const TtrScoreStrip({
    required this.entries,
    this.roundNumber,
    this.totalRounds,
    super.key,
  });

  /// Cumulative score entries, injected.
  final List<ScoreEntry> entries;

  /// 1-based round number; `null` hides the round chip.
  final int? roundNumber;

  /// Total rounds in the match; shown as `Round n / total`.
  final int? totalRounds;

  @override
  Widget build(BuildContext context) {
    final round = roundNumber;
    final roundLabel = round == null
        ? null
        : (totalRounds == null ? 'Round $round' : 'Round $round / $totalRounds');
    return Row(
      children: [
        if (roundLabel != null)
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
                roundLabel,
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
