import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:flutter/material.dart';

/// One attribution row: asset name, source, license.
typedef CreditRow = ({String asset, String source, String license});

/// Current asset attribution (design guide § 7).
// keep in sync with ATTRIBUTION.md
const List<CreditRow> kCreditRows = <CreditRow>[
  (
    asset: 'Fredoka font',
    source: 'github.com/google/fonts (ofl/fredoka)',
    license: 'SIL OFL 1.1',
  ),
  (
    asset: 'Nunito font',
    source: 'github.com/google/fonts (ofl/nunito)',
    license: 'SIL OFL 1.1',
  ),
];

/// Scrollable attribution list mirroring `ATTRIBUTION.md` (legal § 3
/// duty, GDD § 8.1). Body type per design guide § 6.
class CreditsScreen extends StatelessWidget {
  /// Creates the credits screen.
  const CreditsScreen({super.key});

  /// Key of the Fredoka attribution row (tests).
  static const Key fredokaRowKey = Key('credits_fredoka_row');

  /// Key of the Nunito attribution row (tests).
  static const Key nunitoRowKey = Key('credits_nunito_row');

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const TtrAmbientBackdrop(),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(SpacingScale.lg),
                child: Text(
                  'CREDITS',
                  style: TypeScale.title,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingScale.xl,
                  ),
                  itemCount: kCreditRows.length,
                  itemBuilder: (context, index) => _CreditRowCard(
                    row: kCreditRows[index],
                    rowKey: index == 0 ? fredokaRowKey : nunitoRowKey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditRowCard extends StatelessWidget {
  const _CreditRowCard({required this.row, required this.rowKey});

  final CreditRow row;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: rowKey,
      color: ColorPalette.surface,
      margin: const EdgeInsets.only(bottom: SpacingScale.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusScale.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpacingScale.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.asset, style: TypeScale.bodyEmphasis),
            const SizedBox(height: SpacingScale.xs),
            Text(
              row.source,
              style: TypeScale.body.copyWith(color: ColorPalette.neutral700),
            ),
            const SizedBox(height: SpacingScale.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingScale.sm,
                vertical: SpacingScale.xs / 2,
              ),
              decoration: BoxDecoration(
                color: ColorPalette.neutral50,
                borderRadius: BorderRadius.circular(RadiusScale.chip),
              ),
              child: Text(
                row.license.toUpperCase(),
                style: TypeScale.bodyLabel.copyWith(
                  color: ColorPalette.neutral700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
