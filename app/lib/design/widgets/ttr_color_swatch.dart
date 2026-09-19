import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// One player-color swatch for palette pickers (guide § 6: profile
/// palette grid; selection ring = primary). 56px touch target
/// (guide § 8).
class TtrColorSwatch extends StatelessWidget {
  /// Creates a swatch.
  const TtrColorSwatch({
    required this.color,
    required this.selected,
    this.onTap,
    super.key,
  });

  /// The palette color shown.
  final Color color;

  /// Whether this swatch is the current selection (primary ring).
  final bool selected;

  /// Fired on tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusScale.pill),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: ColorPalette.primary, width: 4)
              : Border.all(color: ColorPalette.surface, width: 2),
        ),
      ),
    );
  }
}
