import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
import 'package:flutter/material.dart';

/// Chunky settings card row (guide § 5, replaces raw `ListTile`):
/// surface fill with the `TtrActionButton`-weight neutral900 border,
/// [RadiusScale.card] corners, a Phosphor leading icon, emphasized
/// body title and optional muted subtitle. Optional trailing widget
/// (a `TtrSwitch` or a caret icon).
///
/// Juice (guide § 4): squashes to [MotionScales.press] on press-down
/// when tappable. Touch target ≥ 56px (guide § 8).
class TtrSettingsRow extends StatefulWidget {
  /// Creates the row.
  const TtrSettingsRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// Phosphor Fill icon shown at the row start (guide § 2.1).
  final IconData leading;

  /// Row title (emphasized body type).
  final String title;

  /// Optional muted helper line under the title.
  final String? subtitle;

  /// Optional control at the row end (switch, caret).
  final Widget? trailing;

  /// Fired on row tap; `null` makes the row inert (the trailing
  /// control then owns interaction).
  final VoidCallback? onTap;

  @override
  State<TtrSettingsRow> createState() => _TtrSettingsRowState();
}

class _TtrSettingsRowState extends State<TtrSettingsRow> {
  static const double _leadingIconSize = 24;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;
    return Listener(
      onPointerDown: widget.onTap != null ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TtrPressScale(
        pressed: _pressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingScale.lg,
              vertical: SpacingScale.md,
            ),
            decoration: BoxDecoration(
              color: ColorPalette.surface,
              borderRadius: BorderRadius.circular(RadiusScale.card),
              border: Border.all(
                color: ColorPalette.neutral900,
                width: SpacingScale.xs,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.leading,
                  size: _leadingIconSize,
                  color: ColorPalette.neutral700,
                ),
                const SizedBox(width: SpacingScale.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: TypeScale.bodyEmphasis),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TypeScale.body.copyWith(
                            color: ColorPalette.neutral500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: SpacingScale.md),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
