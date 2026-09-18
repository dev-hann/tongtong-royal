import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:app/presentation/round_intro_screen.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:app/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Builds the screen matching the [ShellController] phase (GDD § 5).
///
/// Dumb switch (architecture doc § 10): the router only maps phase to
/// screen and forwards injected view data; round results and final
/// rankings come from the controller (domain-computed), everything
/// else is passed in by the app shell.
class PhaseRouter extends StatelessWidget {
  /// Creates the phase router.
  const PhaseRouter({
    required this.controller,
    this.lobbyPlayers = const [],
    this.canStart = false,
    this.onStart,
    this.minigameName = '',
    this.minigameRule = '',
    this.countdownValue = 0,
    this.scoreboard = const [],
    this.timeRemaining = '',
    this.onRematch,
    super.key,
  });

  /// The shell controller driving the phase.
  final ShellController controller;

  /// Lobby view data (players currently in the room).
  final List<LobbyPlayer> lobbyPlayers;

  /// Whether the lobby Start button is enabled.
  final bool canStart;

  /// Invoked when the host presses Start in the lobby.
  final VoidCallback? onStart;

  /// Minigame display name for the intro screen.
  final String minigameName;

  /// Minigame one-line rule for the intro screen.
  final String minigameRule;

  /// Countdown value for the intro screen (injected ticker).
  final int countdownValue;

  /// Score strip entries for the game HUD.
  final List<ScoreEntry> scoreboard;

  /// Timer text for the game HUD (host-owned value).
  final String timeRemaining;

  /// Invoked when the players choose a rematch on the podium.
  final VoidCallback? onRematch;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return switch (controller.phase) {
          RoundPhase.lobby => LobbyScreen(
            players: lobbyPlayers,
            canStart: canStart,
            onStart: onStart,
          ),
          RoundPhase.roundIntro => RoundIntroScreen(
            minigameName: minigameName,
            ruleLine: minigameRule,
            countdownValue: countdownValue,
          ),
          RoundPhase.roundPlay => GameScreen(
            scoreboard: scoreboard,
            timeRemaining: timeRemaining,
          ),
          RoundPhase.roundResults => RoundResultsScreen(
            result: controller.latestRoundResult,
          ),
          RoundPhase.podium => PodiumScreen(
            rankings: controller.matchResult?.finalRankings ?? const [],
            onRematch: onRematch,
          ),
        };
      },
    );
  }
}
