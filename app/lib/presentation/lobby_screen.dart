import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_seat_card.dart';
import 'package:flutter/material.dart';

/// View model for one lobby seat (dumb data; rules live in the domain).
@immutable
class LobbyPlayer {
  /// Creates a lobby seat model.
  const LobbyPlayer({
    required this.displayName,
    required this.isReady,
    this.isBot = false,
    this.isLocal = false,
    this.isDisconnected = false,
  });

  /// Name shown on the seat card.
  final String displayName;

  /// Whether this player pressed ready.
  final bool isReady;

  /// Whether this seat is a bot (shows the BOT badge).
  final bool isBot;

  /// Whether this is the local player's seat (tappable color pick).
  final bool isLocal;

  /// Whether this player is currently disconnected.
  final bool isDisconnected;
}

/// LOBBY phase screen: 2x2 grid of seat cards, solo + start actions.
///
/// Pure renderer (architecture doc § 10): all values are passed in;
/// [canStart] is decided elsewhere (domain/host), never here. The
/// local seat's color cycling is presentation-local state only.
class LobbyScreen extends StatelessWidget {
  /// Creates the lobby screen.
  const LobbyScreen({
    required this.players,
    required this.canStart,
    this.onStart,
    this.onSolo,
    super.key,
  });

  /// Key of the Start button (for tests and integration finds).
  static const Key startButtonKey = Key('lobby_start_button');

  /// Key of the Play Solo button (for tests and integration finds).
  static const Key soloButtonKey = Key('lobby_solo_button');

  /// Players currently in the room.
  final List<LobbyPlayer> players;

  /// Whether the Start button is enabled (host + all ready, GDD § 7.1).
  final bool canStart;

  /// Invoked when the host presses Start.
  final VoidCallback? onStart;

  /// Invoked when the player starts a solo match vs bots; when null
  /// (default) no solo button is shown.
  final VoidCallback? onSolo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              padding: const EdgeInsets.all(SpacingScale.lg),
              mainAxisSpacing: SpacingScale.md,
              crossAxisSpacing: SpacingScale.md,
              childAspectRatio: 1.15,
              children: [
                for (final (index, player) in players.indexed)
                  Center(
                    child: TtrSeatCard(
                      nickname: player.displayName,
                      playerColor: PlayerPalette.forIndex(index),
                      isReady: player.isReady && !player.isDisconnected,
                      isBot: player.isBot,
                      isLocal: player.isLocal,
                    ),
                  ),
              ],
            ),
          ),
          if (onSolo != null) ...[
            TtrButton(
              key: soloButtonKey,
              label: 'PLAY SOLO',
              size: TtrButtonSize.large,
              onPressed: onSolo,
            ),
            const SizedBox(height: SpacingScale.sm),
          ],
          TtrButton(
            key: startButtonKey,
            label: 'Start',
            variant: TtrButtonVariant.secondary,
            onPressed: canStart ? onStart : null,
          ),
          const SizedBox(height: SpacingScale.lg),
        ],
      ),
    );
  }
}
