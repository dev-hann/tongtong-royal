import 'package:app/infra/sound_service.dart';

/// In-memory [SfxPlayer] for tests: records plays, optionally
/// throws — no real audio (docs/03 § 10.2.8).
final class FakeSfxPlayer implements SfxPlayer {
  /// Asset path + volume of each accepted play, in order.
  final List<(String, double)> plays = [];

  /// Number of stop calls.
  int stopCalls = 0;

  /// When set, [play] throws this instead of recording.
  StateError? playError;

  /// When set, [stop] throws this instead of counting.
  StateError? stopError;

  @override
  Future<void> play(String assetPath, {double volume = 1.0}) async {
    final error = playError;
    if (error != null) {
      throw error;
    }
    plays.add((assetPath, volume));
  }

  @override
  Future<void> stop() async {
    final error = stopError;
    if (error != null) {
      throw error;
    }
    stopCalls++;
  }
}
