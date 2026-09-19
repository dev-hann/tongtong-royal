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
}
