// Subject: ShowStateMachine (GDD v2 § 5 show flow). The happy-path
// test also walks ShowSchedule starter counts to narrate the
// 4 -> 3 -> 2 -> crown attrition (cross-subject by design: the
// machine owns phase order, the schedule owns field sizes).
import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  /// Drives a fresh machine through [rounds] completed rounds,
  /// leaving it in QUALIFY_FLASH.
  ShowStateMachine playedRounds(int rounds) {
    final machine = ShowStateMachine()..startShow();
    for (var i = 0; i < rounds; i++) {
      machine
        ..startRoundPlay()
        ..endRound();
      if (i < rounds - 1) {
        machine.nextRound();
      }
    }
    return machine;
  }

  test('show_machine_happy_path_4_3_2_crown', () {
    const schedule = ShowSchedule.standard;
    final machine = ShowStateMachine()..startShow();
    expect(machine.phase, ShowPhase.showIntro);
    expect(machine.roundIndex, 1);
    expect(schedule.starterCountFor(1), 4);

    machine
      ..startRoundPlay()
      ..endRound();
    expect(machine.phase, ShowPhase.qualifyFlash);
    expect(machine.roundsCompleted, 1);
    expect(schedule.starterCountFor(2, previousQualified: ['a', 'b', 'c']), 3);

    machine.nextRound();
    expect(machine.phase, ShowPhase.showIntro);
    expect(machine.roundIndex, 2);

    machine
      ..startRoundPlay()
      ..endRound();
    expect(machine.roundsCompleted, 2);
    expect(
      schedule.starterCountFor(3, previousQualified: ['a', 'b']),
      2,
      reason: 'the FINAL starts with the two survivors',
    );

    machine
      ..nextRound()
      ..startRoundPlay()
      ..endRound();
    expect(machine.roundIndex, 3);
    expect(machine.roundsCompleted, 3);
    expect(machine.isShowComplete, isTrue);

    machine.toPodium();
    expect(machine.phase, ShowPhase.podium);
    machine.toLobby();
    expect(machine.phase, ShowPhase.lobby);
    expect(machine.roundsCompleted, 0);
    expect(machine.roundIndex, 1);
  });

  test('show_machine_abandon_legal_phases', () {
    final fromIntro = ShowStateMachine()
      ..startShow()
      ..abandon();
    expect(fromIntro.phase, ShowPhase.lobby);
    expect(fromIntro.roundsCompleted, 0);

    final fromPlay = ShowStateMachine()
      ..startShow()
      ..startRoundPlay()
      ..abandon();
    expect(fromPlay.phase, ShowPhase.lobby);

    final fromFlash = playedRounds(1)..abandon();
    expect(fromFlash.phase, ShowPhase.lobby);
    expect(fromFlash.roundsCompleted, 0);
    expect(fromFlash.roundIndex, 1);
  });

  test('show_machine_abandon_from_podium_throws', () {
    final machine = playedRounds(3)..toPodium();

    expect(
      machine.abandon,
      throwsA(
        isA<InvalidShowTransitionException>().having(
          (e) => e.from,
          'from',
          ShowPhase.podium,
        ),
      ),
    );
  });

  test('show_machine_abandon_from_lobby_throws', () {
    final machine = ShowStateMachine();

    expect(machine.abandon, throwsA(isA<InvalidShowTransitionException>()));
  });

  test('show_machine_round3_forces_podium', () {
    final machine = playedRounds(3);

    expect(machine.isShowComplete, isTrue);
    expect(machine.canTransition(ShowPhase.showIntro), isFalse);
    expect(
      machine.nextRound,
      throwsA(isA<InvalidShowTransitionException>()),
    );
    expect(machine.canTransition(ShowPhase.podium), isTrue);
    machine.toPodium();
    expect(machine.phase, ShowPhase.podium);
  });

  test('show_machine_invalid_transitions_throw', () {
    expect(
      () => ShowStateMachine().transition(ShowPhase.roundPlay),
      throwsA(isA<InvalidShowTransitionException>()),
      reason: 'no show intro skipped into play',
    );

    final inIntro = ShowStateMachine()..startShow();
    expect(
      () => inIntro.transition(ShowPhase.podium),
      throwsA(isA<InvalidShowTransitionException>()),
      reason: 'the crown cannot precede a played round',
    );

    final inPlay = ShowStateMachine()
      ..startShow()
      ..startRoundPlay();
    expect(
      () => inPlay.transition(ShowPhase.showIntro),
      throwsA(isA<InvalidShowTransitionException>()),
      reason: 'a running round cannot rewind to its intro',
    );

    final atPodium = playedRounds(3)..toPodium();
    expect(
      () => atPodium.transition(ShowPhase.showIntro),
      throwsA(isA<InvalidShowTransitionException>()),
      reason: 'the podium only exits to the lobby',
    );
  });

  test('show_machine_can_transition_matrix', () {
    final fromLobby = ShowStateMachine();
    expect(fromLobby.canTransition(ShowPhase.showIntro), isTrue);
    expect(fromLobby.canTransition(ShowPhase.roundPlay), isFalse);
    expect(fromLobby.canTransition(ShowPhase.qualifyFlash), isFalse);
    expect(fromLobby.canTransition(ShowPhase.podium), isFalse);
    expect(fromLobby.canTransition(ShowPhase.lobby), isFalse);

    final fromIntro = ShowStateMachine()..startShow();
    expect(fromIntro.canTransition(ShowPhase.roundPlay), isTrue);
    expect(fromIntro.canTransition(ShowPhase.lobby), isTrue);
    expect(fromIntro.canTransition(ShowPhase.qualifyFlash), isFalse);
    expect(fromIntro.canTransition(ShowPhase.podium), isFalse);

    final fromPlay = ShowStateMachine()
      ..startShow()
      ..startRoundPlay();
    expect(fromPlay.canTransition(ShowPhase.qualifyFlash), isTrue);
    expect(fromPlay.canTransition(ShowPhase.lobby), isTrue);
    expect(fromPlay.canTransition(ShowPhase.showIntro), isFalse);

    final midShowFlash = playedRounds(1);
    expect(midShowFlash.canTransition(ShowPhase.showIntro), isTrue);
    expect(midShowFlash.canTransition(ShowPhase.podium), isFalse);
    expect(midShowFlash.canTransition(ShowPhase.lobby), isTrue);

    final finalFlash = playedRounds(3);
    expect(finalFlash.canTransition(ShowPhase.podium), isTrue);
    expect(finalFlash.canTransition(ShowPhase.showIntro), isFalse);

    final fromPodium = playedRounds(3)..toPodium();
    expect(fromPodium.canTransition(ShowPhase.lobby), isTrue);
    expect(fromPodium.canTransition(ShowPhase.showIntro), isFalse);
    expect(fromPodium.canTransition(ShowPhase.roundPlay), isFalse);
  });
}
