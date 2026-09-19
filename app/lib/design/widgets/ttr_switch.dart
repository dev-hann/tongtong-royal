import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_press_scale.dart';
import 'package:flutter/material.dart';

/// Token-complete custom toggle (guide § 5): chunky toy-box switch
/// replacing the raw material switch tile.
///
/// Track fills with [ColorPalette.primary] when on and
/// [ColorPalette.neutral200] when off; the thumb is a surface circle
/// with the chunky [ColorPalette.neutral900] border (same weight as
/// `TtrActionButton`). No material ripple — the press squash
/// (guide § 4) is the only touch feedback. Sized to sit inline with
/// `TtrButton`-density rows.
class TtrSwitch extends StatefulWidget {
  /// Creates the toggle.
  const TtrSwitch({required this.value, required this.onChanged, super.key});

  /// Whether the toggle is on.
  final bool value;

  /// Fired with the flipped value on tap.
  final ValueChanged<bool> onChanged;

  @override
  State<TtrSwitch> createState() => _TtrSwitchState();
}

class _TtrSwitchState extends State<TtrSwitch> {
  static const double _trackWidth = 52;
  static const double _trackHeight = 32;
  static const double _thumbSize = 24;
  static const double _thumbInset = 2;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: TtrPressScale(
        pressed: _pressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.value),
          child: AnimatedContainer(
            duration: MotionDurations.tap,
            curve: Curves.easeOut,
            width: _trackWidth,
            height: _trackHeight,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: _thumbInset),
            decoration: BoxDecoration(
              color: widget.value
                  ? ColorPalette.primary
                  : ColorPalette.neutral200,
              borderRadius: BorderRadius.circular(RadiusScale.pill),
              border: Border.all(
                color: ColorPalette.neutral900,
                width: SpacingScale.xs,
              ),
            ),
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColorPalette.surface,
                border: Border.all(
                  color: ColorPalette.neutral900,
                  width: SpacingScale.xs,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
