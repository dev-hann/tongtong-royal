import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Variants of [TtrButton].
enum TtrButtonVariant {
  /// Filled with the brand primary color.
  primary,

  /// Filled with the brand secondary color.
  secondary,
}

/// Sizes of [TtrButton].
enum TtrButtonSize {
  /// Default control size.
  regular,

  /// Large game size (lobby primary actions).
  large,
}

/// Shared filled button styled from design tokens.
class TtrButton extends StatelessWidget {
  /// Creates a token-styled button.
  const TtrButton({
    required this.label,
    this.onPressed,
    this.variant = TtrButtonVariant.primary,
    this.size = TtrButtonSize.regular,
    super.key,
  });

  /// Button caption.
  final String label;

  /// Fired on tap; `null` disables the button.
  final VoidCallback? onPressed;

  /// Color variant.
  final TtrButtonVariant variant;

  /// Size variant.
  final TtrButtonSize size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return FilledButton(
      onPressed: onPressed,
      style: _style(enabled),
      child: Text(label),
    );
  }

  ButtonStyle _style(bool enabled) {
    final fill = switch (variant) {
      TtrButtonVariant.primary => ColorPalette.primary,
      TtrButtonVariant.secondary => ColorPalette.secondary,
    };
    final large = size == TtrButtonSize.large;
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(
        enabled ? fill : ColorPalette.neutral200,
      ),
      foregroundColor: const WidgetStatePropertyAll(ColorPalette.onPrimary),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: large ? SpacingScale.xl : SpacingScale.lg,
          vertical: large ? SpacingScale.md : SpacingScale.sm,
        ),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(192, 40)),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: large ? 20 : TypeScale.labelSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusScale.button),
        ),
      ),
      animationDuration: MotionDurations.tap,
    );
  }
}
