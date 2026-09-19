import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:app/presentation/round_intro_screen.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:app/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

export 'package:app/design/game_hud/score_entry.dart' show ScoreEntry;

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
    this.onSolo,
    this.minigameName = '',
    this.minigameRule = '',
    this.countdownValue = 0,
    this.scoreboard = const [],
    this.timeRemaining = '',
    this.resultsMinigameName,
    this.resultsStandings = const [],
    this.resultsAutoAdvanceSeconds,
    this.podiumNicknames = const {},
    this.podiumPlayerColors = const {},
    this.onRematch,
    this.onExitToHome,
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

  /// Invoked when the player starts a solo match vs bots; null shows
  /// no solo button.
  final VoidCallback? onSolo;

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

  /// Display name of the finished round's minigame (results header).
  final String? resultsMinigameName;

  /// Cumulative standings (controller-computed) for the results
  /// screen.
  final List<StandingEntry> resultsStandings;

  /// Host auto-advance dwell in seconds for the results progress bar.
  final int? resultsAutoAdvanceSeconds;

  /// Display names by player id on the podium.
  final Map<String, String> podiumNicknames;

  /// Seat colors by player id on the podium.
  final Map<String, Color> podiumPlayerColors;

  /// Invoked when the players choose a rematch on the podium.
  final VoidCallback? onRematch;

  /// Invoked when the players exit the podium to the home screen.
  final VoidCallback? onExitToHome;

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
            onSolo: onSolo,
          ),
          RoundPhase.roundIntro => RoundIntroScreen(
            minigameName: minigameName,
            ruleLine: minigameRule,
            countdownValue: countdownValue,
            roundNumber: controller.roundIndex + 1,
            totalRounds: controller.totalRounds,
          ),
          RoundPhase.roundPlay => GameScreen(
            scoreboard: scoreboard,
            timeRemaining: timeRemaining,
          ),
          RoundPhase.roundResults => RoundResultsScreen(
            result: controller.latestRoundResult,
            roundNumber: controller.latestRoundResult == null
                ? controller.roundIndex
                : controller.latestRoundResult!.roundIndex + 1,
            totalRounds: controller.totalRounds,
            minigameName: resultsMinigameName,
            standings: resultsStandings,
            autoAdvanceSeconds: resultsAutoAdvanceSeconds,
          ),
          RoundPhase.podium => PodiumScreen(
            rankings: controller.matchResult?.finalRankings ?? const [],
            nicknames: podiumNicknames,
            playerColors: podiumPlayerColors,
            onRematch: onRematch,
            onExit: onExitToHome,
          ),
        };
      },
    );
  }
}
