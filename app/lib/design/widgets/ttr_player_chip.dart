import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// One player row: color dot, nickname, optional BOT badge and a
/// ready/disconnected state label.
///
/// Bots share the seat palette with humans — the badge, not the
/// color, distinguishes them.
class TtrPlayerChip extends StatelessWidget {
  /// Creates the player chip.
  const TtrPlayerChip({
    required this.nickname,
    this.playerColor,
    this.isReady = true,
    this.isBot = false,
    this.isDisconnected = false,
    this.isLocal = false,
    super.key,
  });

  /// Displayed nickname.
  final String nickname;

  /// Seat color of the dot; defaults to seat 1.
  final Color? playerColor;

  /// Whether this player is ready.
  final bool isReady;

  /// Whether this seat is a bot (shows the BOT badge).
  final bool isBot;

  /// Whether this player is currently disconnected.
  final bool isDisconnected;

  /// Whether this is the local player (ring around the dot).
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final dotColor = playerColor ?? PlayerPalette.one;
    final status = isDisconnected
        ? 'Disconnected'
        : (isReady ? 'Ready' : 'Not ready');
    return Opacity(
      opacity: isDisconnected ? 0.55 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: SpacingScale.xl,
            height: SpacingScale.xl,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: isLocal
                  ? Border.all(color: PlayerPalette.localRing, width: 3)
                  : null,
            ),
          ),
          const SizedBox(width: SpacingScale.sm),
          Text(nickname, style: TypeScale.body),
          if (isBot) ...[
            const SizedBox(width: SpacingScale.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingScale.xs,
                vertical: SpacingScale.xs / 2,
              ),
              decoration: BoxDecoration(
                color: ColorPalette.neutral200,
                borderRadius: BorderRadius.circular(RadiusScale.chip),
              ),
              child: Text(
                'BOT',
                style: TypeScale.bodyLabel.copyWith(
                  color: ColorPalette.neutral900,
                ),
              ),
            ),
          ],
          const SizedBox(width: SpacingScale.sm),
          Text(
            status,
            style: TypeScale.bodyLabel.copyWith(
              color: isDisconnected
                  ? ColorPalette.danger
                  : ColorPalette.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}
