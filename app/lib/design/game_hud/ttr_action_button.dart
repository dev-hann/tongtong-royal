import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// The one-button in-game action control (JUMP / DASH).
///
/// Fires on **tap-down** — game-feel demands zero latency between
/// finger contact and jump/dash input; material tap-up semantics
/// are deliberately bypassed.
///
/// Placement guidance: mount at the bottom-center of the game HUD,
/// above the safe-area inset, sized for a thumb.
class TtrActionButton extends StatelessWidget {
  /// Creates the action button.
  const TtrActionButton({
    required this.label,
    required this.onPressed,
    this.onReleased,
    this.enabled = true,
    super.key,
  });

  /// Action caption, e.g. `'JUMP'` / `'DASH'`.
  final String label;

  /// Fired on tap-down (immediate input, game-feel over the
  /// material tap-up delay).
  final VoidCallback onPressed;

  /// Fired on pointer up or cancel (re-arm semantics for
  /// edge-triggered controllers). Optional: omit for one-shot verbs.
  final VoidCallback? onReleased;

  /// Whether the button accepts input.
  final bool enabled;

  static const double _diameter = 96;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Listener(
        onPointerDown: enabled ? (_) => onPressed() : null,
        onPointerUp: enabled ? (_) => onReleased?.call() : null,
        onPointerCancel: enabled ? (_) => onReleased?.call() : null,
        child: Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? ColorPalette.primary : ColorPalette.neutral200,
            border: Border.all(
              color: ColorPalette.neutral900,
              width: SpacingScale.xs,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.labelSize,
                fontWeight: FontWeight.w800,
                color: enabled
                    ? ColorPalette.onPrimary
                    : ColorPalette.neutral500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
