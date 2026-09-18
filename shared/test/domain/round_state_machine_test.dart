import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  test('gdd_5_happy_path_full_match_then_back_to_lobby', () {
    final sm = RoundStateMachine();

    for (var round = 1; round <= MatchRules.roundCount; round++) {
      sm.beginRound();
      expect(sm.phase, RoundPhase.roundIntro);
      sm.startPlay();
      expect(sm.phase, RoundPhase.roundPlay);
      sm.endRound();
      expect(sm.phase, RoundPhase.roundResults);
      expect(sm.roundsCompleted, round);
    }

    sm.toPodium();
    expect(sm.phase, RoundPhase.podium);
    sm.toLobby();
    expect(sm.phase, RoundPhase.lobby);
    expect(sm.roundsCompleted, 0);
  });

  test('gdd_5_after_fifth_results_only_podium_is_allowed', () {
    final sm = RoundStateMachine();
    for (var i = 0; i < MatchRules.roundCount; i++) {
      sm
        ..beginRound()
        ..startPlay()
        ..endRound();
    }

    expect(sm.canTransition(RoundPhase.podium), isTrue);
    expect(sm.canTransition(RoundPhase.roundIntro), isFalse);
    expect(sm.beginRound, throwsA(isA<InvalidTransitionException>()));
  });

  test('gdd_5_before_fifth_results_round_intro_is_allowed', () {
    final sm = RoundStateMachine()
      ..beginRound()
      ..startPlay()
      ..endRound();

    expect(sm.roundsCompleted, 1);
    expect(sm.canTransition(RoundPhase.roundIntro), isTrue);
  });

  test('gdd_7_3_podium_is_reachable_before_five_rounds', () {
    final sm = RoundStateMachine()
      ..beginRound()
      ..startPlay()
      ..endRound();

    expect(sm.canTransition(RoundPhase.podium), isTrue);
    sm.toPodium();
    expect(sm.phase, RoundPhase.podium);
  });

  test('toLobby_resets_round_counter_for_rematch', () {
    final sm = RoundStateMachine()
      ..beginRound()
      ..startPlay()
      ..endRound()
      ..toPodium()
      ..toLobby();

    expect(sm.roundsCompleted, 0);
    for (var i = 0; i < MatchRules.roundCount; i++) {
      sm
        ..beginRound()
        ..startPlay()
        ..endRound();
    }
    expect(sm.roundsCompleted, MatchRules.roundCount);
    expect(sm.canTransition(RoundPhase.podium), isTrue);
  });

  test('invalid_transitions_throw_invalid_transition_exception', () {
    final sm = RoundStateMachine();

    expect(
      () => sm.transition(RoundPhase.roundPlay),
      throwsA(
        isA<InvalidTransitionException>().having(
          (e) => (e.from, e.to),
          'from/to',
          (RoundPhase.lobby, RoundPhase.roundPlay),
        ),
      ),
    );
    expect(sm.phase, RoundPhase.lobby, reason: 'state unchanged after throw');
  });

  test('every_invalid_transition_from_every_phase_throws', () {
    final lobby = RoundStateMachine();
    expect(lobby.canTransition(RoundPhase.podium), isFalse);
    expect(lobby.canTransition(RoundPhase.roundResults), isFalse);

    final intro = RoundStateMachine()..beginRound();
    expect(intro.canTransition(RoundPhase.roundResults), isFalse);
    expect(intro.canTransition(RoundPhase.lobby), isFalse);

    final play = RoundStateMachine()
      ..beginRound()
      ..startPlay();
    expect(play.canTransition(RoundPhase.roundIntro), isFalse);

    final podium = RoundStateMachine()
      ..beginRound()
      ..startPlay()
      ..endRound()
      ..toPodium();
    expect(podium.canTransition(RoundPhase.roundIntro), isFalse);
    expect(podium.canTransition(RoundPhase.roundPlay), isFalse);
  });

  test('self_transition_is_invalid', () {
    final sm = RoundStateMachine();
    expect(sm.canTransition(RoundPhase.lobby), isFalse);
  });
}
