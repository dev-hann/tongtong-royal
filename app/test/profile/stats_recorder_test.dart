import 'package:app/infra/profile_store.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  group('recordShowComplete (showsPlayed, GDD v2 § 7.3)', () {
    test('increments showsPlayed once per call and persists', () async {
      final storage = FakeKeyValueStorage();
      final store = ProfileStore(storage: storage);
      await store.load();
      final recorder = StatsRecorder(store: store);

      await recorder.recordShowComplete();
      await recorder.recordShowComplete();

      expect(store.stats.showsPlayed, 2);

      final reloaded = ProfileStore(storage: storage);
      await reloaded.load();
      expect(reloaded.stats.showsPlayed, 2);
    });
  });

  group('recordFinalReached (finalsReached, GDD v2 § 7.3)', () {
    test('increments finalsReached and persists', () async {
      final storage = FakeKeyValueStorage();
      final store = ProfileStore(storage: storage);
      await store.load();
      final recorder = StatsRecorder(store: store);

      await recorder.recordFinalReached();

      expect(store.stats.finalsReached, 1);

      final reloaded = ProfileStore(storage: storage);
      await reloaded.load();
      expect(reloaded.stats.finalsReached, 1);
    });
  });

  group('recordCrown (crownsWon incl shared, GDD v2 § 2/§ 7.2)', () {
    test('increments crownsWon once per crown won', () async {
      final storage = FakeKeyValueStorage();
      final store = ProfileStore(storage: storage);
      await store.load();
      final recorder = StatsRecorder(store: store);

      await recorder.recordCrown();
      await recorder.recordCrown();

      expect(store.stats.crownsWon, 2);
    });
  });

  group('recordRace (best record, kept from v1 — finishers only)', () {
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
      await store.saveStats(const Stats(bestRaceMs: 42000));

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 41000);

      expect(isNewBest, isTrue);
      expect(store.stats.bestRaceMs, 41000);
    });

    test('recordRace_keeps_existing_best_when_finish_is_slower', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      final recorder = StatsRecorder(store: store);
      await store.saveStats(const Stats(bestRaceMs: 42000));

      final isNewBest = recorder.recordRace(finished: true, elapsedMs: 50000);

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
  });
}
