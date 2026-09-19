import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:flutter/material.dart';

/// Top-left back affordance for pushed routes (guide § 2.1): the
/// system back gesture is hidden in immersive mode, so every pushed
/// screen carries an explicit left-caret pop.
class TtrBackButton extends StatelessWidget {
  /// Creates the back button.
  const TtrBackButton({super.key});

  /// Key of the back button (tests).
  static const Key buttonKey = Key('ttr_back_button');

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(TtrIcons.caretLeft, color: ColorPalette.neutral700),
      tooltip: 'Back',
    );
  }
}
