import 'package:app/profile/profile_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show ErrorDescription, FlutterError, FlutterErrorDetails;

/// One-shot sound effects (GDD § 8.1). Each value carries its asset
/// path under `assets/`.
enum Sfx {
  /// UI tap: buttons and toggles.
  uiTap('sfx/ui_tap.ogg'),

  /// The one-button JUMP press.
  jump('sfx/jump.ogg'),

  /// The human crossed the finish line.
  finish('sfx/finish.ogg'),

  /// Victory fanfare (crown ceremony).
  fanfare('sfx/fanfare.ogg'),

  /// Defeat sting (quiet).
  fail('sfx/fail.ogg'),

  /// Victory ceremony bed loop (crown podium, guide § 9.4).
  victoryLoop('sfx/victory_loop.ogg');

  const Sfx(this.assetPath);

  /// Asset path passed to the player.
  final String assetPath;
}

/// Audio backend seam (tests inject a fake — no real audio in
/// tests, docs/03 § 10.2.8).
abstract interface class SfxPlayer {
  /// Starts the asset playing at [volume] (0..1); fire-and-forget.
  Future<void> play(String assetPath, {double volume});

  /// Stops whatever is currently playing.
  Future<void> stop();
}

/// [SfxPlayer] over a small round-robin [AudioPlayer] pool so
/// overlapping one-shots (rapid jump taps) never cut each other.
final class AudioplayersSfxPlayer implements SfxPlayer {
  /// Creates the pool with [poolSize] players.
  AudioplayersSfxPlayer({int poolSize = 3})
    : _players = List.generate(
        poolSize,
        (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
      );

  final List<AudioPlayer> _players;
  int _next = 0;

  @override
  Future<void> play(String assetPath, {double volume = 1.0}) async {
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    await player.stop();
    await player.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> stop() async {
    for (final player in _players) {
      await player.stop();
    }
  }

  /// Releases the pool's native resources.
  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
  }
}

/// Plays [Sfx] one-shots respecting the persisted sound flag (GDD
/// § 8.1 settings): muting silences instantly (active players are
/// stopped) and later [play] calls become no-ops until unmuted.
///
/// Fire-and-forget: play errors are reported through the injected
/// reporter (default: `FlutterError.reportError`) — never silently
/// swallowed (AGENTS § 6.5).
final class SoundService {
  /// Creates the service over [player], following [profile].
  SoundService({
    required SfxPlayer player,
    required ProfileController profile,
    void Function(String message, Object error)? onError,
  }) : this._(player, profile, onError);

  SoundService._(this._player, this._profile, this._onError) {
    _profile.addListener(_onProfileChanged);
  }

  final SfxPlayer _player;
  final ProfileController _profile;
  final void Function(String message, Object error)? _onError;

  /// Plays [sfx] at [volume]; a no-op while muted.
  void play(Sfx sfx, {double volume = 1.0}) {
    if (!_profile.soundEnabled) {
      return;
    }
    _guard(
      () => _player.play(sfx.assetPath, volume: volume),
      'sfx playback failed: ${sfx.assetPath}',
    );
  }

  /// Stops any active one-shot immediately.
  void stopActive() {
    _guard(_player.stop, 'sfx stop failed');
  }

  /// Detaches from the profile (shell dispose).
  void dispose() {
    _profile.removeListener(_onProfileChanged);
  }

  void _onProfileChanged() {
    if (!_profile.soundEnabled) {
      stopActive();
    }
  }

  void _guard(Future<void> Function() action, String message) {
    action().catchError((Object error) {
      final report = _onError ?? _defaultReport;
      report(message, error);
    });
  }

  static void _defaultReport(String message, Object error) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        library: 'sound_service',
        context: ErrorDescription(message),
      ),
    );
  }
}
