import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:app/infra/profile_store.dart';
import 'package:flutter/material.dart';

/// Stats cards row (matches / wins / 1st places) for the profile
/// screen: Fredoka numerals, staggered entrance (guide § 4, § 6).
class ProfileStatsRow extends StatelessWidget {
  /// Creates the row over [stats].
  const ProfileStatsRow({required this.stats, super.key});

  /// Local match statistics (GDD § 8.1).
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, card) in <(String, int)>[
          ('MATCHES', stats.matchesPlayed),
          ('WINS', stats.wins),
          ('1ST PLACES', stats.firstPlaces),
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
  final int value;

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
            Text(
              '$value',
              style: TypeScale.displayNumeral.copyWith(
                fontSize: TypeScale.headlineSize,
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
