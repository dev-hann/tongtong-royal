import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// Lobby seat card: big color-block avatar, nickname, and state
/// badges (YOU / BOT / Ready).
///
/// The local player's card is tappable and cycles through the seat
/// palette ([PlayerPalette.all]) — a purely local, presentation-level
/// selection; bots keep the palette of their seat.
class TtrSeatCard extends StatefulWidget {
  /// Creates a seat card.
  const TtrSeatCard({
    required this.nickname,
    required this.playerColor,
    this.isReady = true,
    this.isBot = false,
    this.isLocal = false,
    super.key,
  });

  /// Key of the tappable card container (for tests).
  static const Key cardKey = Key('seat_card');

  /// Key of the color-block avatar (for tests).
  static const Key avatarKey = Key('seat_card_avatar');

  /// Displayed nickname.
  final String nickname;

  /// Initial seat color of the avatar.
  final Color playerColor;

  /// Whether this seat is ready.
  final bool isReady;

  /// Whether this seat is a bot (shows the BOT badge).
  final bool isBot;

  /// Whether this is the local player's seat (tappable, YOU badge).
  final bool isLocal;

  @override
  State<TtrSeatCard> createState() => _TtrSeatCardState();
}

class _TtrSeatCardState extends State<TtrSeatCard> {
  late int _colorIndex = PlayerPalette.all.indexOf(widget.playerColor);

  @override
  void didUpdateWidget(TtrSeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerColor != widget.playerColor) {
      _colorIndex = PlayerPalette.all.indexOf(widget.playerColor);
    }
  }

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % PlayerPalette.all.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: TtrSeatCard.cardKey,
      onTap: widget.isLocal ? _cycleColor : null,
      child: Container(
        padding: const EdgeInsets.all(SpacingScale.lg),
        decoration: BoxDecoration(
          color: ColorPalette.surface,
          borderRadius: BorderRadius.circular(RadiusScale.card),
          border: Border.all(
            color: widget.isLocal
                ? ColorPalette.primary
                : ColorPalette.neutral200,
            width: widget.isLocal ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              key: TtrSeatCard.avatarKey,
              decoration: BoxDecoration(
                color: PlayerPalette.all[_colorIndex],
                borderRadius: BorderRadius.circular(RadiusScale.chip),
              ),
              child: const SizedBox(width: 48, height: 48),
            ),
            const SizedBox(height: SpacingScale.sm),
            Text(widget.nickname, style: TypeScale.bodyEmphasis),
            const SizedBox(height: SpacingScale.xs),
            Wrap(
              spacing: SpacingScale.xs,
              runSpacing: SpacingScale.xs,
              alignment: WrapAlignment.center,
              children: [
                if (widget.isBot) const _SeatBadge(label: 'BOT'),
                if (widget.isLocal) const _SeatBadge(label: 'YOU'),
                if (!widget.isBot)
                  _SeatBadge(label: widget.isReady ? 'Ready' : 'Not ready'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.sm,
        vertical: SpacingScale.xs / 2,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.neutral50,
        borderRadius: BorderRadius.circular(RadiusScale.chip),
      ),
      child: Text(
        label,
        style: TypeScale.bodyLabel.copyWith(color: ColorPalette.neutral700),
      ),
    );
  }
}
