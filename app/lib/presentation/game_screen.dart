import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/game_hud/ttr_score_strip.dart';
import 'package:app/design/game_hud/ttr_timer_badge.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

export 'package:app/design/game_hud/score_entry.dart' show ScoreEntry;

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
          padding: const EdgeInsets.all(SpacingScale.sm),
          child: TtrScoreStrip(entries: scoreboard),
        ),
        Expanded(
          child:
              gameView ??
              ColoredBox(
                key: gameViewportKey,
                color: const ArenaPalette().background,
                child: const Center(child: Text('Game placeholder')),
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(SpacingScale.sm),
          child: TtrTimerBadge(key: timerKey, timeLabel: timeRemaining),
        ),
      ],
    );
  }
}
