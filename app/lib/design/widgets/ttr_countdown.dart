import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_pop_on_change.dart';
import 'package:flutter/material.dart';

/// Big countdown number with a pop animation on every change.
///
/// The value is injected (host-owned ticker); this widget owns no
/// timer (architecture doc § 4). Numerals render in the Fredoka
/// SemiBold display role (guide § 2).
class TtrCountdown extends StatelessWidget {
  /// Creates the countdown display.
  const TtrCountdown({required this.value, super.key});

  /// Current countdown value (seconds remaining), injected.
  final int value;

  @override
  Widget build(BuildContext context) {
    return TtrPopOnChange(
      tag: value,
      initialPop: true,
      child: Text('$value', style: TypeScale.displayNumeral),
    );
  }
}
