import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Pop on change (guide § 4): whenever [tag] changes, the child
/// scales 1.0 → [MotionScales.pop] → 1.0 over
/// [MotionDurations.countdownPop]. Set [initialPop] to also fire on
/// first appearance (countdowns).
///
/// Single controller per instance — cheap enough for every HUD
/// numeral.
class TtrPopOnChange extends StatefulWidget {
  /// Creates the pop wrapper.
  const TtrPopOnChange({
    required this.tag,
    required this.child,
    this.initialPop = false,
    super.key,
  });

  /// Identity of the displayed value; a change triggers one pop.
  final Object tag;

  /// The popping content (usually a `Text`).
  final Widget child;

  /// Whether to pop once on first build as well.
  final bool initialPop;

  @override
  State<TtrPopOnChange> createState() => _TtrPopOnChangeState();
}

class _TtrPopOnChangeState extends State<TtrPopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: MotionDurations.countdownPop,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      weight: 40,
      tween: Tween<double>(
        begin: 1,
        end: MotionScales.pop,
      ).chain(CurveTween(curve: Curves.easeOut)),
    ),
    TweenSequenceItem(
      weight: 60,
      tween: Tween<double>(
        begin: MotionScales.pop,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
    ),
  ]).animate(_pop);

  @override
  void initState() {
    super.initState();
    if (widget.initialPop) {
      _pop.forward();
    }
  }

  @override
  void didUpdateWidget(TtrPopOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
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
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
