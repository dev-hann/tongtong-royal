import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// View model for one cumulative-standings row (dumb data): total
/// points plus the delta earned in the round just shown.
@immutable
class StandingEntry {
  /// Creates a standings row.
  const StandingEntry({
    required this.playerId,
    required this.totalPoints,
    required this.roundDelta,
  });

  /// The player this row belongs to.
  final String playerId;

  /// Cumulative points over all completed rounds.
  final int totalPoints;

  /// Points earned in the round being reviewed.
  final int roundDelta;
}

/// Compact cumulative-standings list with this round's delta
/// emphasized next to each name.
///
/// Pure renderer: entries arrive sorted (domain-computed by the
/// controller); rows are displayed verbatim, in the given order.
class TtrStandingsList extends StatelessWidget {
  /// Creates the standings list.
  const TtrStandingsList({required this.entries, super.key});

  /// Standings rows, best first; injected.
  final List<StandingEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in entries)
          Padding(
            key: ValueKey(entry.playerId),
            padding: const EdgeInsets.symmetric(vertical: SpacingScale.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.playerId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: TypeScale.bodySize,
                      fontWeight: FontWeight.w400,
                      color: ColorPalette.onSurface,
                    ),
                  ),
                ),
                SizedBox(
                  width: SpacingScale.xxxl,
                  child: Text(
                    '${entry.totalPoints}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: TypeScale.labelSize,
                      fontWeight: FontWeight.w700,
                      color: ColorPalette.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: SpacingScale.sm),
                _DeltaChip(delta: entry.roundDelta),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final gained = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.sm,
        vertical: SpacingScale.xs / 2,
      ),
      decoration: BoxDecoration(
        color: gained ? ColorPalette.success : ColorPalette.neutral200,
        borderRadius: BorderRadius.circular(RadiusScale.chip),
      ),
      child: Text(
        gained ? '+$delta' : '±0',
        style: TextStyle(
          fontSize: TypeScale.labelSize,
          fontWeight: FontWeight.w600,
          color: gained ? ColorPalette.onSurface : ColorPalette.neutral700,
        ),
      ),
    );
  }
}
