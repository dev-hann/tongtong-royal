import 'dart:async' show Timer;

import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Staggered entrance (guide § 4): wraps one list/grid item so it
/// slides up + fades in over [MotionDurations.staggerItem], starting
/// [MotionDurations.staggerStart] after build plus
/// [MotionDurations.staggerDelay] per [index].
///
/// Runs once per mount; rebuilds (new data, same element) do not
/// replay the entrance.
class TtrStaggeredEntrance extends StatefulWidget {
  /// Creates the entrance wrapper.
  const TtrStaggeredEntrance({
    required this.index,
    required this.child,
    super.key,
  });

  /// Position of the item in the staggered group (0-based).
  final int index;

  /// The animated item.
  final Widget child;

  /// Pure timing math (guide § 4): item [index] starts at
  /// [MotionDurations.staggerStart] + [index] ×
  /// [MotionDurations.staggerDelay].
  static Duration startDelayFor(int index) =>
      MotionDurations.staggerStart + MotionDurations.staggerDelay * index;

  @override
  State<TtrStaggeredEntrance> createState() => _TtrStaggeredEntranceState();
}

class _TtrStaggeredEntranceState extends State<TtrStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: MotionDurations.staggerItem,
  );

  Timer? _start;

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    _start = Timer(TtrStaggeredEntrance.startDelayFor(widget.index), () {
      if (mounted) {
        _entrance.forward();
      }
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
