import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
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
///
/// Juice (guide § 4): squashes to [MotionScales.press] on press-down
/// and springs back over [MotionDurations.tap]. Labels render in the
/// display face with [TypeScale.labelTracking]; the caller passes
/// the caption already UPPERCASE.
class TtrButton extends StatefulWidget {
  /// Creates a token-styled button.
  const TtrButton({
    required this.label,
    this.onPressed,
    this.variant = TtrButtonVariant.primary,
    this.size = TtrButtonSize.regular,
    super.key,
  });

  /// Button caption (UPPERCASE, content-side rule).
  final String label;

  /// Fired on tap; `null` disables the button.
  final VoidCallback? onPressed;

  /// Color variant.
  final TtrButtonVariant variant;

  /// Size variant.
  final TtrButtonSize size;

  @override
  State<TtrButton> createState() => _TtrButtonState();
}

class _TtrButtonState extends State<TtrButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TtrPressScale(
        pressed: _pressed,
        child: FilledButton(
          onPressed: widget.onPressed,
          style: _style(enabled),
          child: Text(widget.label),
        ),
      ),
    );
  }

  ButtonStyle _style(bool enabled) {
    final fill = switch (widget.variant) {
      TtrButtonVariant.primary => ColorPalette.primary,
      TtrButtonVariant.secondary => ColorPalette.secondary,
    };
    final large = widget.size == TtrButtonSize.large;
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
        large ? TypeScale.labelLarge : TypeScale.label,
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
