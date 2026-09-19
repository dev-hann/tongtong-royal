import 'package:tongtong_shared/src/domain/match_rules.dart';

/// Round flow states (GDD § 5).
enum RoundPhase {
  /// Room open, players ready up.
  lobby,

  /// Short intro showing the minigame name and rule one-liner.
  roundIntro,

  /// Minigame running.
  roundPlay,

  /// Placement and points shown after a round.
  roundResults,

  /// Final standings after the last round.
  podium,
}

/// Thrown when a round phase transition is not allowed by the GDD flow.
final class InvalidTransitionException implements Exception {
  /// Creates an exception describing the rejected [from] -> [to] attempt.
  const InvalidTransitionException({required this.from, required this.to});

  /// The phase the machine was in.
  final RoundPhase from;

  /// The phase that was requested.
  final RoundPhase to;

  @override
  String toString() => 'InvalidTransitionException: $from -> $to';
}

/// Owns the round flow of a match (GDD § 5):
/// LOBBY -> ROUND_INTRO -> ROUND_PLAY -> ROUND_RESULTS
/// -> (next ROUND_INTRO | PODIUM | LOBBY).
///
/// After [maxRounds] completed rounds the exits from ROUND_RESULTS are
/// PODIUM (kept for compatibility with multi-round flows) and LOBBY —
/// the single-round ending transition (GDD § 5). Reaching PODIUM
/// earlier is allowed so a match can end immediately when one player
/// remains (GDD § 7.3). Returning to LOBBY resets the round counter
/// for a rematch.
class RoundStateMachine {
  /// Creates a machine starting in [initialPhase].
  RoundStateMachine({
    this.maxRounds = MatchRules.roundCount,
    RoundPhase initialPhase = RoundPhase.lobby,
  }) : _phase = initialPhase,
       _roundsCompleted = 0;

  /// Maximum number of rounds in a match (default: GDD § 2).
  final int maxRounds;

  RoundPhase _phase;
  int _roundsCompleted;

  /// The current phase.
  RoundPhase get phase => _phase;

  /// Number of rounds completed (ROUND_PLAY -> ROUND_RESULTS).
  int get roundsCompleted => _roundsCompleted;

  /// Whether all [maxRounds] rounds have been completed.
  bool get isMatchComplete => _roundsCompleted >= maxRounds;

  /// Whether transition([to]) would succeed from the current phase.
  bool canTransition(RoundPhase to) {
    if (to == _phase) return false;
    return switch (_phase) {
      RoundPhase.lobby => to == RoundPhase.roundIntro,
      RoundPhase.roundIntro =>
        to == RoundPhase.roundPlay || to == RoundPhase.lobby,
      RoundPhase.roundPlay =>
        to == RoundPhase.roundResults || to == RoundPhase.lobby,
      RoundPhase.roundResults =>
        to == RoundPhase.podium ||
            (to == RoundPhase.lobby && isMatchComplete) ||
            (to == RoundPhase.roundIntro && !isMatchComplete),
      RoundPhase.podium => to == RoundPhase.lobby,
    };
  }

  /// Moves to [to], or throws [InvalidTransitionException].
  void transition(RoundPhase to) {
    if (!canTransition(to)) {
      throw InvalidTransitionException(from: _phase, to: to);
    }
    if (_phase == RoundPhase.roundPlay && to == RoundPhase.roundResults) {
      _roundsCompleted++;
    }
    if (to == RoundPhase.lobby) {
      _roundsCompleted = 0;
    }
    _phase = to;
  }

  /// LOBBY or ROUND_RESULTS -> ROUND_INTRO.
  void beginRound() => transition(RoundPhase.roundIntro);

  /// ROUND_INTRO -> ROUND_PLAY.
  void startPlay() => transition(RoundPhase.roundPlay);

  /// ROUND_PLAY -> ROUND_RESULTS; completes one round.
  void endRound() => transition(RoundPhase.roundResults);

  /// ROUND_PLAY -> LOBBY; the local player quits the round mid-play
  /// (GDD § 7.11 solo abandon). No result is recorded and the match
  /// state resets for a fresh match. Legal from ROUND_INTRO (back
  /// during the countdown — nothing at stake) and ROUND_PLAY; the
  /// results screen exits via [toLobby].
  void abandon() {
    if (_phase != RoundPhase.roundPlay && _phase != RoundPhase.roundIntro) {
      throw InvalidTransitionException(from: _phase, to: RoundPhase.lobby);
    }
    transition(RoundPhase.lobby);
  }

  /// ROUND_RESULTS -> PODIUM.
  void toPodium() => transition(RoundPhase.podium);

  /// PODIUM or ROUND_RESULTS (match complete) -> LOBBY; resets the
  /// match for a rematch.
  void toLobby() => transition(RoundPhase.lobby);
}
