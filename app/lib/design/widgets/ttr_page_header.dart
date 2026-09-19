import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:flutter/material.dart';

/// Fixed page header of the FORM archetype (guide § 6): `TtrBackButton`
/// top-left, centered title in the title role, optional [trailing]
/// slot in the top-right (e.g. onboarding SKIP). Padded by
/// [SpacingScale.lg] and ALWAYS mounted outside the scroll area —
/// the header never scrolls with the body.
class TtrPageHeader extends StatelessWidget {
  /// Creates the header.
  const TtrPageHeader({
    required this.title,
    this.showBack = true,
    this.trailing,
    super.key,
  });

  /// Centered header title (caller passes it UPPERCASE).
  final String title;

  /// Whether the back affordance shows; first-launch screens
  /// (onboarding) have nothing to pop.
  final bool showBack;

  /// Optional widget in the top-right header slot.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.all(SpacingScale.lg),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showBack)
            const Align(
              alignment: Alignment.centerLeft,
              child: TtrBackButton(),
            ),
          Text(title, style: TypeScale.title, textAlign: TextAlign.center),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}
