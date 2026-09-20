import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:app/infra/profile_store.dart';
import 'package:flutter/material.dart';

/// Stats cards row (crowns / finals / shows / best time) for the
/// profile screen's RECORD group (GDD v2 § 2): Fredoka numerals,
/// staggered entrance (guide § 4, § 6). The best-time card shows an
/// em dash before the first completed race.
class ProfileStatsRow extends StatelessWidget {
  /// Creates the row over [stats].
  const ProfileStatsRow({required this.stats, this.bestTimeMs, super.key});

  /// Local show statistics (GDD v2 § 2).
  final Stats stats;

  /// Persisted best race time in ms; null when no record exists.
  final int? bestTimeMs;

  @override
  Widget build(BuildContext context) {
    final bestTime = bestTimeMs == null
        ? '—'
        : '${(bestTimeMs! / 1000).toStringAsFixed(2)}s';
    return Row(
      children: [
        for (final (index, card) in <(String, String)>[
          ('CROWNS', '${stats.crownsWon}'),
          ('FINALS', '${stats.finalsReached}'),
          ('SHOWS', '${stats.showsPlayed}'),
          ('BEST TIME', bestTime),
        ].indexed)
          Expanded(
            child: TtrStaggeredEntrance(
              index: index,
              child: _StatCard(label: card.$1, value: card.$2),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColorPalette.surface,
      margin: const EdgeInsets.symmetric(horizontal: SpacingScale.sm / 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusScale.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpacingScale.md),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TypeScale.displayNumeral.copyWith(
                  fontSize: TypeScale.headlineSize,
                ),
              ),
            ),
            const SizedBox(height: SpacingScale.xs),
            Text(
              label,
              style: TypeScale.bodyLabel.copyWith(
                color: ColorPalette.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
