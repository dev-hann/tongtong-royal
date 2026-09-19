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
      ),
    );
  }
}
