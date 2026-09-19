import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Phase-transition wrapper: cross-fades between screens with a
/// slide-up, using [MotionDurations.transition].
///
/// Wrap any shell screen; when the `child` (with a new key) changes,
/// the old screen fades out while the new one slides in from below.
class TtrPhaseTransition extends StatelessWidget {
  /// Creates the transition wrapper.
  const TtrPhaseTransition({required this.child, super.key});

  /// The current screen; give it a per-phase [Key] to trigger the
  /// transition.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MotionDurations.transition,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final inAnimation = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: inAnimation, child: child),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: child,
    );
  }
}
