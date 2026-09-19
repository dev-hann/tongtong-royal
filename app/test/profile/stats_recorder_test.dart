import 'package:app/infra/profile_store.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  test('recordMatch increments matchesPlayed only for rank > 1', () async {
    final store = ProfileStore(storage: FakeKeyValueStorage());
    await store.load();
    final recorder = StatsRecorder(store: store);

    await recorder.recordMatch(finalRank: 2);

    expect(store.stats.matchesPlayed, 1);
    expect(store.stats.wins, 0);
    expect(store.stats.firstPlaces, 0);
  });

  test('recordMatch increments wins and firstPlaces for rank 1', () async {
    final store = ProfileStore(storage: FakeKeyValueStorage());
    await store.load();
    final recorder = StatsRecorder(store: store);

    await recorder.recordMatch(finalRank: 1);

    expect(store.stats.matchesPlayed, 1);
    expect(store.stats.wins, 1);
    expect(store.stats.firstPlaces, 1);
  });

  test('recordMatch accumulates across matches and persists', () async {
    final storage = FakeKeyValueStorage();
    final store = ProfileStore(storage: storage);
    await store.load();
    final recorder = StatsRecorder(store: store);

    await recorder.recordMatch(finalRank: 3);
    await recorder.recordMatch(finalRank: 1);
    await recorder.recordMatch(finalRank: 1);

    expect(store.stats.matchesPlayed, 3);
    expect(store.stats.wins, 2);
    expect(store.stats.firstPlaces, 2);

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.stats.matchesPlayed, 3);
    expect(reloaded.stats.wins, 2);
  });

  group('recordRace (best record, GDD § 8.1)', () {
    test('recordRace_returns_true_and_saves_first_finished_time', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 42000);

      expect(isNewBest, isTrue);
      expect(store.stats.bestRaceMs, 42000);
    });

    test('recordRace_replaces_best_when_finish_is_faster', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      // Arrange: an existing 42 s record.
      await store.saveStats(const Stats(bestRaceMs: 42000));

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 41000);

      expect(isNewBest, isTrue);
      expect(store.stats.bestRaceMs, 41000);
    });

    test('recordRace_keeps_existing_best_when_finish_is_slower', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      // Arrange: an existing 42 s record.
      await store.saveStats(const Stats(bestRaceMs: 42000));

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 50000);

      expect(isNewBest, isFalse);
      expect(store.stats.bestRaceMs, 42000);
    });

    test('recordRace_equal_time_is_not_a_new_best', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      // Arrange: an existing 42 s record.
      await store.saveStats(const Stats(bestRaceMs: 42000));

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 42000);

      expect(isNewBest, isFalse);
      expect(store.stats.bestRaceMs, 42000);
    });

    test('recordRace_timeout_ranked_round_never_records', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      final isNewBest = recorder.recordRace(finished: false, elapsedMs: 90000);

      expect(isNewBest, isFalse);
      expect(store.stats.bestRaceMs, isNull);
    });

    test('recordRace_missing_elapsed_time_never_records', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);

      final isNewBest = recorder.recordRace(finished: true);

      expect(isNewBest, isFalse);
      expect(store.stats.bestRaceMs, isNull);
    });
  });
}
