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

/// Local match statistics (GDD § 8.1), recorded at podium confirm.
@immutable
final class Stats {
  /// Creates a stats record; all counters default to zero.
  const Stats({this.matchesPlayed = 0, this.wins = 0, this.firstPlaces = 0});

  /// Matches the player confirmed at the podium.
  final int matchesPlayed;

  /// Matches finished at final rank 1.
  final int wins;

  /// Same as [wins] (first-place finishes); kept as a separate
  /// counter per GDD § 8.1 wording.
  final int firstPlaces;

  @override
  bool operator ==(Object other) =>
      other is Stats &&
      other.matchesPlayed == matchesPlayed &&
      other.wins == wins &&
      other.firstPlaces == firstPlaces;

  @override
  int get hashCode => Object.hash(matchesPlayed, wins, firstPlaces);
}

/// Local app settings (GDD § 8.1).
@immutable
final class Settings {
  /// Creates settings with defaults.
  const Settings({this.soundEnabled = true});

  /// Master sound flag (audio engine lands with M5; persisted now).
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
  static const String _matchesPlayedKey = 'ttr.stats.matchesPlayed';
  static const String _winsKey = 'ttr.stats.wins';
  static const String _firstPlacesKey = 'ttr.stats.firstPlaces';
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
      matchesPlayed: await storage.getInt(_matchesPlayedKey) ?? 0,
      wins: await storage.getInt(_winsKey) ?? 0,
      firstPlaces: await storage.getInt(_firstPlacesKey) ?? 0,
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
    await storage.setInt(_matchesPlayedKey, value.matchesPlayed);
    await storage.setInt(_winsKey, value.wins);
    await storage.setInt(_firstPlacesKey, value.firstPlaces);
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
