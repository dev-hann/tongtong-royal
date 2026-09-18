import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Big countdown number with a pop-in animation on every change.
///
/// The value is injected (host-owned ticker); this widget owns no
/// timer (architecture doc § 4).
class TtrCountdown extends StatefulWidget {
  /// Creates the countdown display.
  const TtrCountdown({required this.value, super.key});

  /// Current countdown value (seconds remaining), injected.
  final int value;

  @override
  State<TtrCountdown> createState() => _TtrCountdownState();
}

class _TtrCountdownState extends State<TtrCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: MotionDurations.countdownPop,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.4,
    end: 1,
  ).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _pop.forward();
  }

  @override
  void didUpdateWidget(TtrCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Text(
        '${widget.value}',
        style: const TextStyle(
          fontSize: TypeScale.displaySize,
          fontWeight: FontWeight.w800,
          color: ColorPalette.onSurface,
        ),
      ),
    );
  }
}
