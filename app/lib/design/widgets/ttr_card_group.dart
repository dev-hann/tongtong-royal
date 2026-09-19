import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';

/// FORM content unit (guide § 6): an optional section label
/// (labelLarge role, uppercase, tracked, [ColorPalette.neutral500],
/// left-aligned) above a rounded surface container
/// ([ColorPalette.surface], [RadiusScale.card], neutral200 border at
/// the `TtrSettingsRow` border weight) holding a stretched column of
/// [children] — `TtrSettingsRow`s or custom content. Actions inside
/// stretch full width (Form Law: `CrossAxisAlignment.stretch`).
///
/// Stagger (guide § 4): pass [staggerIndex] to slide the whole group
/// in as one entrance item; callers sequence groups 0, 1, 2...
class TtrCardGroup extends StatelessWidget {
  /// Creates the group.
  const TtrCardGroup({
    required this.children,
    this.label,
    this.staggerIndex,
    super.key,
  });

  /// Section label; uppercased for display. `null` renders the card
  /// alone (unlabelled single-section forms).
  final String? label;

  /// Card content rows, stretched to the group width and separated
  /// by [SpacingScale.sm] gutters.
  final List<Widget> children;

  /// Staggered-entrance index for the whole group; `null` disables
  /// the entrance.
  final int? staggerIndex;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final group = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(
              left: SpacingScale.sm,
              bottom: SpacingScale.sm,
            ),
            child: Text(
              label.toUpperCase(),
              style: TypeScale.labelLarge.copyWith(
                color: ColorPalette.neutral500,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(SpacingScale.md),
          decoration: BoxDecoration(
            color: ColorPalette.surface,
            borderRadius: BorderRadius.circular(RadiusScale.card),
            border: Border.all(
              color: ColorPalette.neutral200,
              width: SpacingScale.xs,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: SpacingScale.sm),
                child,
              ],
            ],
          ),
        ),
      ],
    );
    final staggerIndex = this.staggerIndex;
    if (staggerIndex == null) {
      return group;
    }
    return TtrStaggeredEntrance(index: staggerIndex, child: group);
  }
}
