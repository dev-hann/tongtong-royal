import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Short-lived feedback message styled from tokens.
class TtrToast extends StatelessWidget {
  /// Creates the toast.
  const TtrToast({required this.message, super.key});

  /// Message shown to the player.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingScale.md),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.card),
        border: Border.all(color: ColorPalette.primary, width: SpacingScale.xs),
        boxShadow: const [
          BoxShadow(
            color: ColorPalette.neutral900,
            blurRadius: SpacingScale.md,
            offset: Offset(0, SpacingScale.xs),
          ),
        ],
      ),
      child: Text(message, style: TypeScale.body),
    );
  }
}
