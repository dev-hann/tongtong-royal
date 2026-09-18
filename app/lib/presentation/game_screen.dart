import 'package:flutter/material.dart';

/// View model for one HUD score-strip entry (dumb data).
@immutable
class ScoreEntry {
  /// Creates a score entry.
  const ScoreEntry({required this.playerId, required this.points});

  /// The player this score belongs to.
  final String playerId;

  /// Cumulative points of the player.
  final int points;
}

/// ROUND_PLAY phase shell: HUD chrome around the Flame game viewport.
///
/// Pure renderer: timer and scores are injected values (host-owned,
/// architecture doc § 4); the Flame widget is mounted by the game
/// layer through [gameView] — this screen holds no game logic.
class GameScreen extends StatelessWidget {
  /// Creates the game screen shell.
  const GameScreen({
    required this.scoreboard,
    required this.timeRemaining,
    this.gameView,
    super.key,
  });

  /// Key of the game viewport slot (for tests and integration finds).
  static const Key gameViewportKey = Key('game_viewport');

  /// Key of the HUD timer text (for tests and integration finds).
  static const Key timerKey = Key('game_timer');

  /// Cumulative score strip entries, injected.
  final List<ScoreEntry> scoreboard;

  /// Timer text (e.g. seconds left), injected from host state.
  final String timeRemaining;

  /// Slot where the game layer mounts the Flame widget.
  final Widget? gameView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final entry in scoreboard)
                Text('${entry.playerId}: ${entry.points}'),
            ],
          ),
        ),
        Expanded(
          child: gameView ??
              const ColoredBox(
                key: gameViewportKey,
                color: Color(0xFF101820),
                child: Center(child: Text('Game placeholder')),
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            timeRemaining,
            key: timerKey,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }
}
