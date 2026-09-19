import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:flutter/material.dart';

/// Opaque page surface for pushed routes (guide § 6 + ux-checklist):
/// [Scaffold] with the token background (so the route transition
/// never shows the black barrier), the ambient backdrop on top, and
/// the content SafeArea-protected.
///
/// Every pushed screen uses this shell — bare `Stack(backdrop, ...)`
/// routes render black wherever the decorative circles do not cover.
class TtrPageShell extends StatelessWidget {
  /// Creates the page shell around [child].
  const TtrPageShell({required this.child, super.key});

  /// The page content, laid out inside the safe area.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const TtrAmbientBackdrop(),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
