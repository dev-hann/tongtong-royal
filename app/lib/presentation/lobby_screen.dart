import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_player_chip.dart';
import 'package:flutter/material.dart';

/// View model for one lobby row (dumb data; rules live in the domain).
@immutable
class LobbyPlayer {
  /// Creates a lobby row model.
  const LobbyPlayer({
    required this.displayName,
    required this.isReady,
    this.isBot = false,
    this.isDisconnected = false,
  });

  /// Name shown in the lobby list.
  final String displayName;

  /// Whether this player pressed ready.
  final bool isReady;

  /// Whether this seat is a bot (shows the BOT badge).
  final bool isBot;

  /// Whether this player is currently disconnected.
  final bool isDisconnected;
}

/// LOBBY phase screen: player list, ready badges, Start button.
///
/// Pure renderer (architecture doc § 10): all values are passed in;
/// [canStart] is decided elsewhere (domain/host), never here.
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(SpacingScale.lg),
            children: [
              for (final (index, player) in players.indexed)
                Padding(
                  key: ValueKey(player.displayName),
                  padding: const EdgeInsets.symmetric(
                    vertical: SpacingScale.xs,
                  ),
                  child: TtrPlayerChip(
                    nickname: player.displayName,
                    playerColor: PlayerPalette.forIndex(index),
                    isReady: player.isReady,
                    isBot: player.isBot,
                    isDisconnected: player.isDisconnected,
                  ),
                ),
            ],
          ),
        ),
        TtrButton(
          key: startButtonKey,
          label: 'Start',
          size: TtrButtonSize.large,
          onPressed: canStart ? onStart : null,
        ),
        if (onSolo != null)
          Padding(
            padding: const EdgeInsets.only(top: SpacingScale.sm),
            child: TtrButton(
              key: soloButtonKey,
              label: 'Play Solo (vs bots)',
              variant: TtrButtonVariant.secondary,
              onPressed: onSolo,
            ),
          ),
      ],
    );
  }
}
