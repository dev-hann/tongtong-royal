import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Emphasis pulse (guide § 4): repeating 1.0 → [MotionScales.pulse]
/// scale at [MotionDurations.pulse]. Exactly ONE pulsing element per
/// screen — more is noise.
class TtrPulse extends StatefulWidget {
  /// Creates the pulse wrapper.
  const TtrPulse({required this.child, super.key});

  /// The pulsing content.
  final Widget child;

  @override
  State<TtrPulse> createState() => _TtrPulseState();
}

class _TtrPulseState extends State<TtrPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: MotionDurations.pulse,
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: MotionScales.pulse,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
