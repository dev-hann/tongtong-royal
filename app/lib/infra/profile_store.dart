import 'package:flutter/foundation.dart' show immutable;
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal async key-value seam over persistent storage. Production
/// uses [SharedPreferencesStorage]; tests inject a fake — no real
/// preferences in unit tests.
abstract interface class KeyValueStorage {
  /// Reads a string; null when absent.
  Future<String?> getString(String key);

  /// Writes a string.
  Future<void> setString(String key, String value);

  /// Reads a bool; null when absent.
  Future<bool?> getBool(String key);

  /// Writes a bool.
  Future<void> setBool(String key, {required bool value});

  /// Reads an int; null when absent.
  Future<int?> getInt(String key);

  /// Writes an int.
  Future<void> setInt(String key, int value);
}

/// [KeyValueStorage] over [SharedPreferences].
final class SharedPreferencesStorage implements KeyValueStorage {
  const SharedPreferencesStorage._(this._prefs);

  /// Creates the adapter over the shared preferences singleton.
  static Future<SharedPreferencesStorage> create() async =>
      SharedPreferencesStorage._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      _prefs.setString(key, value);

  @override
  Future<bool?> getBool(String key) async => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      _prefs.setBool(key, value);

  @override
  Future<int?> getInt(String key) async => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) async => _prefs.setInt(key, value);
}

/// Local player identity (GDD § 8.1): display nickname and palette
/// index. Value type — compare by fields.
@immutable
final class Profile {
  /// Creates a profile; defaults per GDD § 8.1.
  const Profile({this.nickname = defaultNickname, this.colorIndex = 0});

  /// Default nickname when none is stored or the input is empty.
  static const String defaultNickname = 'PLAYER';

  /// Display nickname (already validated on write).
  final String nickname;

  /// PlayerPalette index (0..3) of the player's color.
  final int colorIndex;

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.nickname == nickname &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(nickname, colorIndex);
}

/// Local show statistics (GDD v2 § 2 — crown-centered), recorded at
/// the crown-moments below; the v1 placement counters
/// (matches/wins/firstPlaces) were repealed with the v1 results
/// flow. Migration: v1 keys stay untouched in storage and are
/// ignored on load — counts restart fresh (documented decision,
/// GDD v2 § 2 repeals the v1 stats system wholesale).
@immutable
final class Stats {
  /// Creates a stats record; all counters default to zero.
  const Stats({
    this.showsPlayed = 0,
    this.finalsReached = 0,
    this.crownsWon = 0,
    this.bestRaceMs,
  });

  /// Shows completed (PODIUM or elimination summary appearance,
  /// GDD v2 § 7.3 — never at start, never on abandonment).
  final int showsPlayed;

  /// Times the player STARTED the FINAL round (GDD v2 § 7.3).
  final int finalsReached;

  /// Finals won, shared crowns included (GDD v2 § 7.2).
  final int crownsWon;

  /// Fastest completed-race finish time in milliseconds (kept from
  /// v1; finishers only — timeout-ranked rounds never set records);
  /// null before the first completed race.
  final int? bestRaceMs;

  @override
  bool operator ==(Object other) =>
      other is Stats &&
      other.showsPlayed == showsPlayed &&
      other.finalsReached == finalsReached &&
      other.crownsWon == crownsWon &&
      other.bestRaceMs == bestRaceMs;

  @override
  int get hashCode => Object.hash(
    showsPlayed,
    finalsReached,
    crownsWon,
    bestRaceMs,
  );
}

/// Local app settings (GDD § 8.1).
@immutable
final class Settings {
  /// Creates settings with defaults.
  const Settings({this.soundEnabled = true});

  /// Master sound flag (gates the SFX engine instantly).
  final bool soundEnabled;

  @override
  bool operator ==(Object other) =>
      other is Settings && other.soundEnabled == soundEnabled;

  @override
  int get hashCode => Object.hashAll([soundEnabled]);
}

/// SharedPreferences-backed local store for the profile, stats and
/// settings (GDD § 8.1, local-only — no network, no sync).
///
/// Async [load] once at startup, then cached synchronous getters;
/// every save writes through to [storage] and refreshes the cache.
final class ProfileStore {
  /// Creates a store over [storage]; call [load] before reading.
  ProfileStore({required this.storage});

  /// Creates a production store over shared preferences, loaded.
  static Future<ProfileStore> create() async {
    final store = ProfileStore(
      storage: await SharedPreferencesStorage.create(),
    );
    await store.load();
    return store;
  }

  /// Persistent key-value seam (fake in tests).
  final KeyValueStorage storage;

  static const String _nicknameKey = 'ttr.profile.nickname';
  static const String _colorIndexKey = 'ttr.profile.colorIndex';
  static const String _onboardedKey = 'ttr.profile.onboarded';
  static const String _showsPlayedKey = 'ttr.stats.showsPlayed';
  static const String _finalsReachedKey = 'ttr.stats.finalsReached';
  static const String _crownsWonKey = 'ttr.stats.crownsWon';
  static const String _bestRaceMsKey = 'ttr.stats.bestRaceMs';
  static const String _soundEnabledKey = 'ttr.settings.soundEnabled';

  Profile _profile = const Profile();
  Stats _stats = const Stats();
  Settings _settings = const Settings();
  bool _onboarded = false;

  /// Loads every persisted value into the cache (defaults when
  /// absent).
  Future<void> load() async {
    _profile = Profile(
      nickname:
          await storage.getString(_nicknameKey) ?? Profile.defaultNickname,
      colorIndex: await storage.getInt(_colorIndexKey) ?? 0,
    );
    _stats = Stats(
      showsPlayed: await storage.getInt(_showsPlayedKey) ?? 0,
      finalsReached: await storage.getInt(_finalsReachedKey) ?? 0,
      crownsWon: await storage.getInt(_crownsWonKey) ?? 0,
      bestRaceMs: await storage.getInt(_bestRaceMsKey),
    );
    _settings = Settings(
      soundEnabled: await storage.getBool(_soundEnabledKey) ?? true,
    );
    _onboarded = await storage.getBool(_onboardedKey) ?? false;
  }

  /// Cached player identity (post-[load]).
  Profile get profile => _profile;

  /// Cached match statistics (post-[load]).
  Stats get stats => _stats;

  /// Cached settings (post-[load]).
  Settings get settings => _settings;

  /// Whether onboarding was completed once (first-launch gate).
  bool get onboarded => _onboarded;

  /// Persists the nickname and refreshes the cache (cache first, so
  /// synchronous readers observe the new value immediately).
  Future<void> saveNickname(String value) async {
    _profile = Profile(nickname: value, colorIndex: _profile.colorIndex);
    await storage.setString(_nicknameKey, value);
  }

  /// Persists the palette index and refreshes the cache.
  Future<void> saveColorIndex(int value) async {
    _profile = Profile(nickname: _profile.nickname, colorIndex: value);
    await storage.setInt(_colorIndexKey, value);
  }

  /// Persists the stats record and refreshes the cache.
  Future<void> saveStats(Stats value) async {
    _stats = value;
    await storage.setInt(_showsPlayedKey, value.showsPlayed);
    await storage.setInt(_finalsReachedKey, value.finalsReached);
    await storage.setInt(_crownsWonKey, value.crownsWon);
    final best = value.bestRaceMs;
    if (best != null) {
      await storage.setInt(_bestRaceMsKey, best);
    }
  }

  /// Persists the sound flag and refreshes the cache.
  Future<void> saveSoundEnabled({required bool value}) async {
    _settings = Settings(soundEnabled: value);
    await storage.setBool(_soundEnabledKey, value: value);
  }

  /// Marks onboarding completed (never shown again, GDD § 8.1).
  Future<void> markOnboarded() async {
    _onboarded = true;
    await storage.setBool(_onboardedKey, value: true);
  }
}
