import 'dart:async' show unawaited;

import 'package:app/infra/sound_service.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Fires the ROUND_RESULTS side effects exactly once per match
/// (GDD § 8.1): stats recording, best-record tracking and the
/// results sound cues. The shell calls [handle] on every phase
/// change; only the first ROUND_RESULTS per match acts. [reset]
/// re-arms it for the next match (PLAY AGAIN / new solo).
final class ShellResultsFlow {
  /// Creates the flow over [recorder] with optional [sound] cues.
  ShellResultsFlow({required this.recorder, this.sound});

  /// Local stats sink (matches, wins, best record).
  final StatsRecorder recorder;

  /// Sound cue hook; null = silent (tests without audio).
  final SoundService? sound;

  bool _recorded = false;
  bool _newBest = false;

  /// Whether the handled result set a new best record.
  bool get isNewBest => _newBest;

  /// Handles one shell phase change; acts only the first time the
  /// terminal ROUND_RESULTS appears for the running match.
  void handle({required ShellController shell, SoloMatchController? solo}) {
    if (shell.phase != RoundPhase.roundResults || _recorded) {
      return;
    }
    if (solo == null) {
      return;
    }
    final human = Rankings.finalRanking(
      shell.roundResults,
      const {},
    ).finalRankings.where((p) => p.playerId == solo.humanId).toList();
    if (human.isEmpty) {
      return;
    }
    _recorded = true;
    final rank = human.first.rank;
    // Stats are best-effort local persistence; a failed write must
    // not block the results screen.
    unawaited(recorder.recordMatch(finalRank: rank));
    final elapsedMs = solo.humanFinishMs;
    _newBest = recorder.recordRace(
      finished: elapsedMs != null,
      elapsedMs: elapsedMs,
    );
    _cue(rank: rank, finished: elapsedMs != null);
  }

  /// Re-arms the flow for the next match (GDD § 5 PLAY AGAIN /
  /// fresh solo start).
  void reset() {
    _recorded = false;
    _newBest = false;
  }

  /// Results cues: rank 1 gets the finish chime + fanfare; any
  /// other finisher the chime; a timed-out human the quiet fail
  /// sting.
  void _cue({required int rank, required bool finished}) {
    final sound = this.sound;
    if (sound == null) {
      return;
    }
    if (rank == 1) {
      sound
        ..play(Sfx.finish)
        ..play(Sfx.fanfare);
    } else if (finished) {
      sound.play(Sfx.finish);
    } else {
      sound.play(Sfx.fail, volume: 0.5);
    }
  }
}
