import 'package:app/infra/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_key_value_storage.dart';

void main() {
  group('ProfileStore defaults (fresh storage)', () {
    test('profile/stats/settings defaults before and after load', () async {
      final storage = FakeKeyValueStorage();
      final store = ProfileStore(storage: storage);

      expect(store.profile, const Profile());
      expect(store.stats, const Stats());
      expect(store.settings, const Settings());
      expect(store.onboarded, isFalse);

      await store.load();

      expect(store.profile.nickname, 'PLAYER');
      expect(store.profile.colorIndex, 0);
      expect(store.stats.matchesPlayed, 0);
      expect(store.stats.wins, 0);
      expect(store.stats.firstPlaces, 0);
      expect(store.settings.soundEnabled, isTrue);
      expect(store.onboarded, isFalse);
    });
  });

  group('ProfileStore save/load roundtrip', () {
    test('saved profile survives reload through the storage', () async {
      final storage = FakeKeyValueStorage();
      final first = ProfileStore(storage: storage);
      await first.load();
      await first.saveNickname('HANN');
      await first.saveColorIndex(2);
      await first.markOnboarded();

      final second = ProfileStore(storage: storage);
      await second.load();

      expect(second.profile.nickname, 'HANN');
      expect(second.profile.colorIndex, 2);
      expect(second.onboarded, isTrue);
    });

    test('saved stats survive reload through the storage', () async {
      final storage = FakeKeyValueStorage();
      final first = ProfileStore(storage: storage);
      await first.load();
      await first.saveStats(
        const Stats(matchesPlayed: 3, wins: 1, firstPlaces: 1),
      );

      final second = ProfileStore(storage: storage);
      await second.load();

      expect(second.stats.matchesPlayed, 3);
      expect(second.stats.wins, 1);
      expect(second.stats.firstPlaces, 1);
    });

    test('saved settings survive reload through the storage', () async {
      final storage = FakeKeyValueStorage();
      final first = ProfileStore(storage: storage);
      await first.load();
      await first.saveSoundEnabled(value: false);

      final second = ProfileStore(storage: storage);
      await second.load();

      expect(second.settings.soundEnabled, isFalse);
    });

    test('mutations are cached synchronously after save', () async {
      final store = ProfileStore(storage: FakeKeyValueStorage());
      await store.load();
      await store.saveNickname('ACE');
      await store.saveColorIndex(3);

      expect(store.profile.nickname, 'ACE');
      expect(store.profile.colorIndex, 3);
    });
  });

  group('ProfileStore key namespaces', () {
    test('all keys live under ttr.profile/stats/settings', () async {
      final storage = FakeKeyValueStorage();
      final store = ProfileStore(storage: storage);
      await store.load();
      await store.saveNickname('ACE');
      await store.saveColorIndex(1);
      await store.markOnboarded();
      await store.saveSoundEnabled(value: false);
      await store.saveStats(
        const Stats(matchesPlayed: 1, wins: 1, firstPlaces: 1),
      );

      expect(storage.values.keys, everyElement(contains('ttr.')));
      expect(storage.values.containsKey('ttr.profile.nickname'), isTrue);
      expect(storage.values.containsKey('ttr.profile.colorIndex'), isTrue);
      expect(storage.values.containsKey('ttr.profile.onboarded'), isTrue);
      expect(storage.values.containsKey('ttr.settings.soundEnabled'), isTrue);
      expect(storage.values.containsKey('ttr.stats.matchesPlayed'), isTrue);
      expect(storage.values.containsKey('ttr.stats.wins'), isTrue);
      expect(storage.values.containsKey('ttr.stats.firstPlaces'), isTrue);
    });
  });

  group('value semantics', () {
    test('Profile/Stats/Settings compare by field values', () {
      expect(const Profile(), const Profile());
      expect(const Profile(nickname: 'ACE'), const Profile(nickname: 'ACE'));
      expect(const Stats(matchesPlayed: 2), const Stats(matchesPlayed: 2));
      expect(
        const Settings(soundEnabled: false),
        const Settings(soundEnabled: false),
      );
      expect(const Profile(colorIndex: 1), isNot(const Profile()));
    });
  });
}
