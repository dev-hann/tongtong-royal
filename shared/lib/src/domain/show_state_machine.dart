import 'package:tongtong_shared/src/domain/show_schedule.dart';

/// Show flow states (GDD v2 § 5).
enum ShowPhase {
  /// Home; no show running.
  lobby,

  /// 3-second intro: round pill + game banner.
  showIntro,

  /// Minigame running.
  roundPlay,

  /// Qualified/eliminated reveal (replaces v1 ROUND_RESULTS).
  qualifyFlash,

  /// Crown ceremony.
  podium,
}

/// Thrown when a show phase transition is not allowed by GDD § 5.
final class InvalidShowTransitionException implements Exception {
  /// Creates an exception describing the rejected [from] -> [to]
  /// attempt.
  const InvalidShowTransitionException({required this.from, required this.to});

  /// The phase the machine was in.
  final ShowPhase from;

  /// The phase that was requested.
  final ShowPhase to;

  @override
  String toString() => 'InvalidShowTransitionException: $from -> $to';
}

/// Owns the flow of one show (GDD v2 § 5):
/// LOBBY -> SHOW_INTRO -> ROUND_PLAY -> QUALIFY_FLASH
/// -> (next SHOW_INTRO | PODIUM), PODIUM -> LOBBY.
///
/// [roundIndex] is one-based (1..[roundCount]) matching
/// `ShowSchedule` slots; `RoundEvents.roundIndex` (zero-based, v1)
/// is `roundIndex - 1` — the show runtime performs the mapping.
/// After [roundCount] completed rounds the only exit from
/// QUALIFY_FLASH is PODIUM (the show always crowns). Abandoning
/// (GDD § 7.4) is legal from every in-show phase back to LOBBY and
/// resets all counters; returning to LOBBY resets the machine for
/// a rematch.
class ShowStateMachine {
  /// Creates a machine starting in [initialPhase] with a maximum of
  /// [roundCount] rounds.
  ShowStateMachine({
    this.roundCount = ShowSchedule.roundCount,
    ShowPhase initialPhase = ShowPhase.lobby,
  }) : _phase = initialPhase,
       _roundsCompleted = 0,
       _roundIndex = 1;

  /// Rounds per show (GDD § 1: exactly 3).
  final int roundCount;

  ShowPhase _phase;
  int _roundsCompleted;
  int _roundIndex;

  /// The current phase.
  ShowPhase get phase => _phase;

  /// One-based index of the current (upcoming or running) round.
  int get roundIndex => _roundIndex;

  /// Number of completed rounds (ROUND_PLAY -> QUALIFY_FLASH).
  int get roundsCompleted => _roundsCompleted;

  /// Whether all [roundCount] rounds have been completed.
  bool get isShowComplete => _roundsCompleted >= roundCount;

  /// Whether transition([to]) would succeed from the current phase.
  bool canTransition(ShowPhase to) {
    if (to == _phase) return false;
    return switch (_phase) {
      ShowPhase.lobby => to == ShowPhase.showIntro,
      ShowPhase.showIntro =>
        to == ShowPhase.roundPlay || to == ShowPhase.lobby,
      ShowPhase.roundPlay =>
        to == ShowPhase.qualifyFlash || to == ShowPhase.lobby,
      ShowPhase.qualifyFlash =>
        (to == ShowPhase.showIntro && !isShowComplete) ||
            (to == ShowPhase.podium && isShowComplete) ||
            to == ShowPhase.lobby,
      ShowPhase.podium => to == ShowPhase.lobby,
    };
  }

  /// Moves to [to], or throws [InvalidShowTransitionException].
  void transition(ShowPhase to) {
    if (!canTransition(to)) {
      throw InvalidShowTransitionException(from: _phase, to: to);
    }
    if (_phase == ShowPhase.roundPlay && to == ShowPhase.qualifyFlash) {
      _roundsCompleted++;
    }
    if (_phase == ShowPhase.qualifyFlash && to == ShowPhase.showIntro) {
      _roundIndex++;
    }
    if (to == ShowPhase.lobby) {
      _roundsCompleted = 0;
      _roundIndex = 1;
    }
    _phase = to;
  }

  /// LOBBY -> SHOW_INTRO; opens the show at round 1.
  void startShow() => transition(ShowPhase.showIntro);

  /// SHOW_INTRO -> ROUND_PLAY.
  void startRoundPlay() => transition(ShowPhase.roundPlay);

  /// ROUND_PLAY -> QUALIFY_FLASH; completes one round.
  void endRound() => transition(ShowPhase.qualifyFlash);

  /// QUALIFY_FLASH -> next SHOW_INTRO; advances the round index.
  /// Throws when the show is complete — the crown waits at
  /// [toPodium].
  void nextRound() => transition(ShowPhase.showIntro);

  /// QUALIFY_FLASH (show complete) -> PODIUM.
  void toPodium() => transition(ShowPhase.podium);

  /// PODIUM -> LOBBY; resets the machine for a rematch.
  void toLobby() => transition(ShowPhase.lobby);

  /// In-show phases -> LOBBY (GDD § 7.4 abandon): no stats are
  /// recorded and every counter resets. Illegal from LOBBY and
  /// PODIUM — nothing is at stake there.
  void abandon() {
    if (_phase != ShowPhase.showIntro &&
        _phase != ShowPhase.roundPlay &&
        _phase != ShowPhase.qualifyFlash) {
      throw InvalidShowTransitionException(from: _phase, to: ShowPhase.lobby);
    }
    transition(ShowPhase.lobby);
  }
}
