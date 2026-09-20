import 'package:app/design/tokens.dart';
import 'package:app/infra/sound_service.dart';
import 'package:app/presentation/elimination_summary_screen.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:app/presentation/qualify_flash_screen.dart';
import 'package:app/presentation/show_play_view.dart';
import 'package:app/show/show_controller.dart';
import 'package:app/show/show_round_session.dart' show ShowRoundSession;
import 'package:app/show/show_view_data.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Screen builders for the shell's show phases (kept here so the
/// scaffold file stays within the repo line limit, docs/05 § 2).
/// Pure wiring: every value comes from the controller.

/// Seat colors for the current roster (human keeps the profile
/// color, GDD v2 § 8.1).
Map<PlayerId, Color> showSeatColors(ShowController show) => {
  for (final (index, seat) in show.seats.indexed)
    seat.id: PlayerPalette.forSeat(
      index,
      localIndex: show.config.humanColorIndex,
    ),
};

/// ROUND_PLAY: the mounted round inside the game-screen HUD shell.
Widget showPlayScreen({required ShowController show, SoundService? sound}) {
  final session = show.currentRound;
  return GameScreen(
    scoreboard: const [],
    timeRemaining: '',
    remainingSeconds: show.remainingSeconds,
    roundNumber: show.roundIndex,
    totalRounds: show.roundCount,
    gameView: session == null
        ? null
        : KeyedSubtree(
            key: ValueKey<ShowRoundSession>(session),
            child: ShowPlayView(
              session: session,
              seatColors: showSeatColors(show),
              sound: sound,
              onQuit: show.abandonShow,
            ),
          ),
  );
}

/// QUALIFY_FLASH: verdict chips from the domain result (qualified
/// first, then eliminated — champions first in the FINAL).
Widget showFlashScreen(ShowController show) {
  final verdict = show.latestVerdict;
  if (verdict == null) {
    return const ColoredBox(color: ColorPalette.background);
  }
  final colors = showSeatColors(show);
  return QualifyFlashScreen(
    entries: [
      for (final id in verdict.qualified)
        _flashEntry(show, colors, id, qualified: true),
      for (final id in verdict.eliminated)
        _flashEntry(show, colors, id, qualified: false),
    ],
    quota: show.verdictQuota,
    isFinal: verdict.isFinal,
    humanEliminated: verdict.eliminated.contains(show.config.humanId),
    onAdvanceNow: show.skipFlash,
  );
}

QualifyFlashEntry _flashEntry(
  ShowController show,
  Map<PlayerId, Color> colors,
  PlayerId id, {
  required bool qualified,
}) {
  final verdict = show.latestVerdict!;
  return QualifyFlashEntry(
    playerId: id,
    nickname: show.seatOf(id).nickname,
    color: colors[id] ?? PlayerPalette.one,
    qualified: qualified,
    isChampion: verdict.isFinal && verdict.champions.contains(id),
    isLocal: id == show.config.humanId,
  );
}

/// PODIUM: the crown ceremony over the judged champions.
Widget showPodiumScreen(
  ShowController show, {
  VoidCallback? onPlayAgain,
  VoidCallback? onExitHome,
}) {
  final colors = showSeatColors(show);
  final champions = show.champions ?? const <PlayerId>[];
  return PodiumScreen(
    champions: [
      for (final champion in champions)
        PodiumPlayer(
          playerId: champion,
          nickname: show.seatOf(champion).nickname,
          color: colors[champion] ?? PlayerPalette.one,
          isLocal: champion == show.config.humanId,
        ),
    ],
    humanWon: champions.contains(show.config.humanId),
    onPlayAgain: onPlayAgain,
    onExitHome: onExitHome,
  );
}

/// Elimination summary (GDD v2 § 7.3): own verdict + the simulated
/// champion line + stat deltas.
Widget showSummaryScreen(
  ShowController show, {
  VoidCallback? onPlayAgain,
  VoidCallback? onExitHome,
}) {
  final summary = show.summary!;
  final championNames = [
    for (final champion in summary.champions)
      show.seatOf(champion).nickname,
  ];
  final championLine = championNames.length == 1
      ? '${championNames.single} takes the crown'
      : '${championNames.join(' and ')} share the crown';
  return EliminationSummaryScreen(
    eliminatedInRound: summary.eliminatedInRound,
    championLine: championLine,
    statDeltas: const ['SHOWS +1'],
    onPlayAgain: onPlayAgain,
    onExitHome: onExitHome,
  );
}
