import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Standings view data exposed additively on
/// [SoloMatchController] (kept here so the controller file stays
/// within the repo line limit).
///
/// All computation goes through the domain ([Rankings.finalRanking]
/// over the shell's recorded results) — nothing is re-scored here.
extension SoloMatchStandings on SoloMatchController {
  /// Cumulative points per seat over completed rounds, best first.
  List<ScoreEntry> get standings => [
    for (final placement in Rankings.finalRanking(
      shell.roundResults,
      const {},
    ).finalRankings)
      ScoreEntry(playerId: placement.playerId, points: placement.points),
  ];

  /// Results-screen standings: cumulative totals plus the latest
  /// round's delta (domain-ranked); empty before any round completes.
  List<StandingEntry> get standingsAfterLatestRound {
    final latest = shell.latestRoundResult;
    if (latest == null) {
      return const [];
    }
    final deltas = {
      for (final placement in latest.placements)
        placement.playerId: placement.points,
    };
    return [
      for (final entry in standings)
        StandingEntry(
          playerId: entry.playerId,
          totalPoints: entry.points,
          roundDelta: deltas[entry.playerId] ?? 0,
        ),
    ];
  }
}
