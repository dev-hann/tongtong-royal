import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
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
  (asset: 'Phosphor Icons (Fill)', source: 'phosphoricons.com', license: 'MIT'),
  (
    asset: 'Sound effects',
    source: 'generated placeholders (ffmpeg synthesis)',
    license: 'CC0-equivalent',
  ),
];

/// Scrollable attribution list mirroring `ATTRIBUTION.md` (legal § 3
/// duty, GDD § 8.1). Guide § 6 FORM: fixed header over one
/// `TtrCardGroup` labelled ASSETS — the group surface provides the
/// card chrome, rows are plain body-type content. Body type per
/// design guide § 6.
class CreditsScreen extends StatelessWidget {
  /// Creates the credits screen.
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TtrPageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TtrPageHeader(title: 'CREDITS'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SpacingScale.xl),
              child: TtrCardGroup(
                label: 'ASSETS',
                staggerIndex: 0,
                children: [
                  for (final row in kCreditRows)
                    _CreditRowCard(
                      row: row,
                      rowKey: Key('credits_row_${row.asset}'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditRowCard extends StatelessWidget {
  const _CreditRowCard({required this.row, required this.rowKey});

  final CreditRow row;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: SpacingScale.sm),
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
    );
  }
}
