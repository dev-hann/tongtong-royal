import 'package:app/design/tokens.dart';
import 'package:app/infra/profile_store.dart';
import 'package:flutter/foundation.dart';

/// Presentation-side controller over the local [ProfileStore].
///
/// Owns nickname validation (GDD § 8.1): trim, 1-12 chars, empty or
/// whitespace-only falls back to [Profile.defaultNickname]; longer
/// input is rejected (caller keeps the previous value and may show
/// an error). Color selection clamps into the [PlayerPalette] range.
final class ProfileController extends ChangeNotifier {
  /// Creates a controller over [store]; call [load] before use.
  ProfileController({required this.store});

  /// Maximum nickname length (validated after trim).
  static const int maxNicknameLength = 12;

  /// The persistent local store.
  final ProfileStore store;

  /// Loads the store cache.
  Future<void> load() => store.load();

  /// Cached player identity.
  Profile get profile => store.profile;

  /// Cached match statistics.
  Stats get stats => store.stats;

  /// Cached sound flag.
  bool get soundEnabled => store.settings.soundEnabled;

  /// Whether first-launch onboarding is still due.
  bool get needsOnboarding => !store.onboarded;

  /// Validates and persists a nickname. Returns whether the input
  /// was accepted (false: longer than [maxNicknameLength] after
  /// trim — nothing is saved).
  Future<bool> setNickname(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.length > maxNicknameLength) {
      return false;
    }
    await store.saveNickname(
      trimmed.isEmpty ? Profile.defaultNickname : trimmed,
    );
    notifyListeners();
    return true;
  }

  /// Selects the palette color, clamped to [PlayerPalette] length.
  void selectColor(int index) {
    final clamped = index.clamp(0, PlayerPalette.all.length - 1);
    if (clamped == store.profile.colorIndex) {
      return;
    }
    store.saveColorIndex(clamped);
    notifyListeners();
  }

  /// Persists the sound flag.
  Future<void> setSoundEnabled({required bool value}) async {
    await store.saveSoundEnabled(value: value);
    notifyListeners();
  }

  /// Marks onboarding completed (first-launch gate, shown once).
  Future<void> completeOnboarding() async {
    await store.markOnboarded();
    notifyListeners();
  }
}
