import 'dart:async' show unawaited;

import 'package:app/infra/profile_store.dart';

/// Records local match statistics when the results screen appears
/// (GDD § 8.1).
///
/// Thin presentation-side logic over [ProfileStore]: matchesPlayed
/// +1 per confirmed match; wins and firstPlaces +1 iff the final
/// rank is 1. The domain stays oblivious — the wiring layer passes
/// the already-judged final rank in.
final class StatsRecorder {
  /// Creates a recorder writing through [store].
  const StatsRecorder({required this.store});

  /// The persistent store stats are written to.
  final ProfileStore store;

  /// Records one confirmed match finished at [finalRank] (1-based).
  Future<void> recordMatch({required int finalRank}) async {
    final current = store.stats;
    final won = finalRank == 1;
    await store.saveStats(
      Stats(
        matchesPlayed: current.matchesPlayed + 1,
        wins: current.wins + (won ? 1 : 0),
        firstPlaces: current.firstPlaces + (won ? 1 : 0),
        bestRaceMs: current.bestRaceMs,
      ),
    );
  }

  /// Records one race's finish time against the best record (GDD
  /// § 8.1): only finishers count ([finished] true with an
  /// [elapsedMs]); a strictly faster time replaces the record; an
  /// equal time is NOT a new best. Returns whether a new record
  /// was set — decided synchronously from the store cache (the
  /// write-through is best-effort like [recordMatch]).
  bool recordRace({required bool finished, int? elapsedMs}) {
    final current = store.stats;
    final best = current.bestRaceMs;
    final isNewBest =
        finished && elapsedMs != null && (best == null || elapsedMs < best);
    if (isNewBest) {
      unawaited(
        store.saveStats(
          Stats(
            matchesPlayed: current.matchesPlayed,
            wins: current.wins,
            firstPlaces: current.firstPlaces,
            bestRaceMs: elapsedMs,
          ),
        ),
      );
    }
    return isNewBest;
  }
}
