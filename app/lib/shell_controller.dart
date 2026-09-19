import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Presentation-shell wiring over the domain [RoundStateMachine].
///
/// The controller owns no game rules (architecture doc § 10): it
/// forwards phase transitions to the state machine, stores the
/// domain-provided [RoundResult]s, and asks the domain
/// ([Rankings.finalRanking]) for final standings when the podium is
/// reached (compatibility path — the single-round shell ends at
/// ROUND_RESULTS, GDD § 5). Invalid transitions propagate the
/// machine's [InvalidTransitionException] — nothing is swallowed.
class ShellController extends ChangeNotifier {
  /// Creates a controller wrapping [stateMachine] (or a fresh machine).
  ShellController({RoundStateMachine? stateMachine})
    : _machine = stateMachine ?? RoundStateMachine();

  final RoundStateMachine _machine;
  final List<RoundResult> _roundResults = [];

  RoundResult? _latestRoundResult;
  MatchResult? _matchResult;

  /// The current round phase.
  RoundPhase get phase => _machine.phase;

  /// Zero-based index of the round being set up or played.
  int get roundIndex => _machine.roundsCompleted;

  /// The most recently delivered round result, if any.
  RoundResult? get latestRoundResult => _latestRoundResult;

  /// Results of all completed rounds, in completion order (input for
  /// HUD standings and cumulative views).
  List<RoundResult> get roundResults => List.unmodifiable(_roundResults);

  /// Maximum rounds in the current match (GDD § 2).
  int get totalRounds => _machine.maxRounds;

  /// Final standings; only set while the phase is [RoundPhase.podium].
  MatchResult? get matchResult => _matchResult;

  /// LOBBY -> ROUND_INTRO for the first round (host pressed Start).
  void startMatch() => _apply(_machine.beginRound);

  /// LOBBY or ROUND_RESULTS -> ROUND_INTRO for the next round.
  void beginRound() => _apply(_machine.beginRound);

  /// ROUND_INTRO -> ROUND_PLAY.
  void startPlay() => _apply(_machine.startPlay);

  /// ROUND_PLAY -> ROUND_RESULTS, recording the domain-judged [result].
  void endRound(RoundResult result) {
    _apply(() {
      _machine.endRound();
      _roundResults.add(result);
      _latestRoundResult = result;
    });
  }

  /// ROUND_RESULTS -> PODIUM; final standings come from the domain.
  /// Kept for compatibility (multi-round flows); the single-round
  /// shell ends at ROUND_RESULTS instead (GDD § 5).
  void toPodium() {
    _apply(() {
      _machine.toPodium();
      _matchResult = Rankings.finalRanking(_roundResults, const {});
    });
  }

  /// PODIUM or ROUND_RESULTS (match complete) -> LOBBY; clears
  /// per-match state for a rematch.
  void toLobby() {
    _apply(() {
      _machine.toLobby();
      _roundResults.clear();
      _latestRoundResult = null;
      _matchResult = null;
    });
  }

  /// ROUND_PLAY -> LOBBY without a result (solo abandon, GDD § 7.11):
  /// clears per-match state so nothing records stats.
  void abandonMatch() {
    _apply(() {
      _machine.abandon();
      _roundResults.clear();
      _latestRoundResult = null;
      _matchResult = null;
    });
  }

  /// Runs [action] (which may throw [InvalidTransitionException]) and
  /// notifies listeners only when it succeeded.
  void _apply(void Function() action) {
    action();
    notifyListeners();
  }
}
