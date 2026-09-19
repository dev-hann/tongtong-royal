import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Button press squash (guide § 4): scales the child toward
/// [MotionScales.press] while the pointer is down and springs back
/// over [MotionDurations.tap].
///
/// Controller-driven (not implicitly animated) so releasing
/// mid-squash reverses smoothly from the current scale instead of
/// snapping.
class TtrPressScale extends StatefulWidget {
  /// Creates the squash wrapper.
  const TtrPressScale({required this.pressed, required this.child, super.key});

  /// Whether the wrapped control is currently pressed.
  final bool pressed;

  /// The squashing control.
  final Widget child;

  @override
  State<TtrPressScale> createState() => _TtrPressScaleState();
}

class _TtrPressScaleState extends State<TtrPressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: MotionDurations.tap,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: MotionScales.press,
  ).animate(CurvedAnimation(parent: _squash, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    if (widget.pressed) {
      _squash.value = 1;
    }
  }

  @override
  void didUpdateWidget(TtrPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pressed == oldWidget.pressed) {
      return;
    }
    widget.pressed ? _squash.forward() : _squash.reverse();
  }

  @override
  void dispose() {
    _squash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
