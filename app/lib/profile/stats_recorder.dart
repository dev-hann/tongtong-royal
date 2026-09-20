import 'dart:async' show unawaited;

import 'package:app/infra/profile_store.dart';

/// Records local show statistics at the GDD v2 § 7.3 write-moments:
/// `showsPlayed` once at PODIUM or the elimination summary,
/// `finalsReached` when the player starts the FINAL, `crownsWon` per
/// crown (shared crowns included, GDD v2 § 7.2).
///
/// Thin presentation-side logic over [ProfileStore]: the domain stays
/// oblivious — the wiring layer decides when a moment happened. All
/// writes are read-modify-write through the store cache and persist
/// best-effort (a failed write must not block a ceremony screen).
final class StatsRecorder {
  /// Creates a recorder writing through [store].
  const StatsRecorder({required this.store});

  /// The persistent store stats are written to.
  final ProfileStore store;

  /// Records one completed show (PODIUM or elimination summary).
  Future<void> recordShowComplete() async {
    final current = store.stats;
    await store.saveStats(
      Stats(
        showsPlayed: current.showsPlayed + 1,
        finalsReached: current.finalsReached,
        crownsWon: current.crownsWon,
        bestRaceMs: current.bestRaceMs,
      ),
    );
  }

  /// Records that the player started the FINAL round.
  Future<void> recordFinalReached() async {
    final current = store.stats;
    await store.saveStats(
      Stats(
        showsPlayed: current.showsPlayed,
        finalsReached: current.finalsReached + 1,
        crownsWon: current.crownsWon,
        bestRaceMs: current.bestRaceMs,
      ),
    );
  }

  /// Records one crown won (call once per show, shared or solo).
  Future<void> recordCrown() async {
    final current = store.stats;
    await store.saveStats(
      Stats(
        showsPlayed: current.showsPlayed,
        finalsReached: current.finalsReached,
        crownsWon: current.crownsWon + 1,
        bestRaceMs: current.bestRaceMs,
      ),
    );
  }

  /// Records one race's finish time against the best record (kept
  /// from v1): only finishers count ([finished] true with an
  /// [elapsedMs]); a strictly faster time replaces the record; an
  /// equal time is NOT a new best. Returns whether a new record was
  /// set — decided synchronously from the store cache.
  bool recordRace({required bool finished, int? elapsedMs}) {
    final current = store.stats;
    final best = current.bestRaceMs;
    final isNewBest =
        finished && elapsedMs != null && (best == null || elapsedMs < best);
    if (isNewBest) {
      unawaited(
        store.saveStats(
          Stats(
            showsPlayed: current.showsPlayed,
            finalsReached: current.finalsReached,
            crownsWon: current.crownsWon,
            bestRaceMs: elapsedMs,
          ),
        ),
      );
    }
    return isNewBest;
  }
}
