import 'package:flutter/material.dart';

/// View model for one lobby row (dumb data; rules live in the domain).
@immutable
class LobbyPlayer {
  /// Creates a lobby row model.
  const LobbyPlayer({required this.displayName, required this.isReady});

  /// Name shown in the lobby list.
  final String displayName;

  /// Whether this player pressed ready.
  final bool isReady;
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
    super.key,
  });

  /// Key of the Start button (for tests and integration finds).
  static const Key startButtonKey = Key('lobby_start_button');

  /// Players currently in the room.
  final List<LobbyPlayer> players;

  /// Whether the Start button is enabled (host + all ready, GDD § 7.1).
  final bool canStart;

  /// Invoked when the host presses Start.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final player in players)
                ListTile(
                  key: ValueKey(player.displayName),
                  title: Text(player.displayName),
                  trailing: Text(player.isReady ? 'Ready' : 'Not ready'),
                ),
            ],
          ),
        ),
        ElevatedButton(
          key: startButtonKey,
          onPressed: canStart ? onStart : null,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
