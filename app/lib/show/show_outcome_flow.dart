import 'dart:async' show unawaited;

import 'package:app/infra/sound_service.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:app/show/show_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Fires the show's side effects at the GDD v2 § 7.3 write-moments:
/// stats (`showsPlayed` once at PODIUM or the elimination summary,
/// `finalsReached` when the human starts the FINAL, `crownsWon` per
/// crown incl. shared, best race time from finisher ticks) and the
/// ceremony sound cues (qualify flash → finish sting; crown →
/// fanfare + victory loop; human elimination → fail sting). The
/// shell calls [handle] on every controller notification; every
/// guard is per-show-instance inside, so a fresh show simply starts
/// producing new moments.
///
/// Design stays pure: this flow is wiring, never a rule.
final class ShowResultsFlow {
  /// Creates the flow over [recorder] with optional [sound] cues.
  ShowResultsFlow({required this.recorder, this.sound});

  /// Local stats sink (crowns, finals, shows, best record).
  final StatsRecorder recorder;

  /// Sound cue hook; null = silent (tests without audio).
  final SoundService? sound;

  bool _finalsReached = false;
  bool _showCompleted = false;
  bool _crownRecorded = false;
  bool _ceremonyCued = false;
  int? _lastRaceRound;
  int? _lastCueRound;

  /// Handles one controller notification; acts only on the moments.
  void handle(ShowController show) {
    _maybeRecordFinalsReached(show);
    _maybeRecordRace(show);
    _maybeCompleteShow(show);
    _maybeRecordCrown(show);
    _maybeCueVerdict(show);
    _maybeCueCeremony(show);
  }

  void _maybeRecordFinalsReached(ShowController show) {
    if (_finalsReached) {
      return;
    }
    final session = show.currentRound;
    if (show.phase != ShowPhase.roundPlay ||
        show.roundIndex != show.roundCount ||
        session == null ||
        !session.rosterIds.contains(show.config.humanId)) {
      return;
    }
    _finalsReached = true;
    unawaited(
      recorder.recordFinalReached().catchError((Object error) {
        // Best-effort local persistence: a failed write must not
        // break the FINAL.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'show_outcome_flow',
            context: ErrorDescription('recordFinalReached failed'),
          ),
        );
      }),
    );
  }

  void _maybeRecordRace(ShowController show) {
    if (show.phase != ShowPhase.qualifyFlash ||
        show.verdictRoundIndex == _lastRaceRound) {
      return;
    }
    _lastRaceRound = show.verdictRoundIndex;
    final elapsedMs = show.humanFinishMs;
    if (elapsedMs == null) {
      return; // non-finisher (timeout-ranked): records need a finisher
    }
    recorder.recordRace(finished: true, elapsedMs: elapsedMs);
  }

  void _maybeCompleteShow(ShowController show) {
    if (_showCompleted) {
      return;
    }
    if (show.phase != ShowPhase.podium && show.summary == null) {
      return;
    }
    _showCompleted = true;
    unawaited(
      recorder.recordShowComplete().catchError((Object error) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'show_outcome_flow',
            context: ErrorDescription('recordShowComplete failed'),
          ),
        );
      }),
    );
  }

  void _maybeRecordCrown(ShowController show) {
    if (_crownRecorded || show.phase != ShowPhase.podium) {
      return;
    }
    final champions = show.champions;
    if (champions == null || !champions.contains(show.config.humanId)) {
      return;
    }
    _crownRecorded = true;
    unawaited(
      recorder.recordCrown().catchError((Object error) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'show_outcome_flow',
            context: ErrorDescription('recordCrown failed'),
          ),
        );
      }),
    );
  }

  /// QUALIFY_FLASH cue: human qualified → finish sting; human
  /// eliminated → fail sting; a FINAL the human WON → fanfare (the
  /// podium ceremony adds the victory loop).
  void _maybeCueVerdict(ShowController show) {
    if (show.phase != ShowPhase.qualifyFlash ||
        show.verdictRoundIndex == _lastCueRound) {
      return;
    }
    _lastCueRound = show.verdictRoundIndex;
    final sound = this.sound;
    if (sound == null) {
      return;
    }
    final verdict = show.latestVerdict;
    if (verdict == null) {
      return;
    }
    if (verdict.isFinal) {
      if (verdict.champions.contains(show.config.humanId)) {
        sound.play(Sfx.fanfare);
      } else {
        sound.play(Sfx.fail, volume: 0.5);
      }
    } else if (verdict.qualified.contains(show.config.humanId)) {
      sound.play(Sfx.finish);
    } else {
      sound.play(Sfx.fail, volume: 0.5);
    }
  }

  /// PODIUM ceremony cue: fanfare + victory loop bed (scope § 5).
  void _maybeCueCeremony(ShowController show) {
    if (show.phase != ShowPhase.podium || _ceremonyCued) {
      return;
    }
    _ceremonyCued = true;
    final sound = this.sound;
    if (sound == null) {
      return;
    }
    sound
      ..play(Sfx.fanfare)
      ..play(Sfx.victoryLoop);
  }
}
