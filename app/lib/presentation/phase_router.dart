import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/round_intro_screen.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:app/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

export 'package:app/design/game_hud/score_entry.dart' show ScoreEntry;

/// Builds the screen matching the [ShellController] phase (GDD § 5).
///
/// Dumb switch (architecture doc § 10): the router only maps phase to
/// screen and forwards injected view data; round results come from
/// the controller (domain-computed), everything else is passed in by
/// the app shell. The single-round shell never routes through
/// [RoundPhase.podium] (GDD § 5: the machine keeps the transition,
/// the MVP shell ends at ROUND_RESULTS).
class PhaseRouter extends StatelessWidget {
  /// Creates the phase router.
  const PhaseRouter({
    required this.controller,
    this.lobbyPlayers = const [],
    this.lobbyLocalColorIndex = 0,
    this.canStart = false,
    this.onStart,
    this.onSolo,
    this.minigameName = '',
    this.minigameRule = '',
    this.countdownValue = 0,
    this.onAbandonIntro,
    this.scoreboard = const [],
    this.timeRemaining = '',
    this.resultsMinigameName,
    this.resultsStandings = const [],
    this.onPlayAgain,
    this.onExitHome,
    super.key,
  });

  /// The shell controller driving the phase.
  final ShellController controller;

  /// Lobby view data (players currently in the room).
  final List<LobbyPlayer> lobbyPlayers;

  /// Palette index of the local player's profile color; forwarded to
  /// the lobby seat grid (seat 0 renders it, others avoid it).
  final int lobbyLocalColorIndex;

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

  /// Abandons the match when system back fires during ROUND_INTRO
  /// (ux-checklist back matrix).
  final VoidCallback? onAbandonIntro;

  /// Score strip entries for the game HUD.
  final List<ScoreEntry> scoreboard;

  /// Timer text for the game HUD (host-owned value).
  final String timeRemaining;

  /// Display name of the finished round's minigame (results header).
  final String? resultsMinigameName;

  /// Standings (controller-computed) for the results screen.
  final List<StandingEntry> resultsStandings;

  /// Invoked when the player chooses PLAY AGAIN on the results
  /// screen (fresh match, GDD § 5).
  final VoidCallback? onPlayAgain;

  /// Invoked when the player exits the results screen to home
  /// (GDD § 5).
  final VoidCallback? onExitHome;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return switch (controller.phase) {
          RoundPhase.lobby => LobbyScreen(
            players: lobbyPlayers,
            canStart: canStart,
            localColorIndex: lobbyLocalColorIndex,
            onStart: onStart,
            onSolo: onSolo,
          ),
          RoundPhase.roundIntro => RoundIntroScreen(
            minigameName: minigameName,
            ruleLine: minigameRule,
            countdownValue: countdownValue,
            onAbandon: onAbandonIntro,
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
            onPlayAgain: onPlayAgain,
            onExitHome: onExitHome,
          ),
          // The single-round shell never routes through PODIUM
          // (GDD § 5); reaching it here is a wiring bug, not a flow.
          RoundPhase.podium => throw UnsupportedError(
            'phase router does not route through podium',
          ),
        };
      },
    );
  }
}
