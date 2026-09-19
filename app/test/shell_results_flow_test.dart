import 'package:app/infra/profile_store.dart';
import 'package:app/infra/sound_service.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:app/shell_controller.dart';
import 'package:app/shell_results_flow.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'infra/fake_key_value_storage.dart';
import 'infra/fake_sfx_player.dart';
import 'solo/fake_solo_scheduler.dart';
import 'solo/fake_solo_sim.dart';

/// Scripted sim where the human finishes first (tick 1, bots after).
final class _HumanWinsSim extends FakeSoloSim {
  _HumanWinsSim({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 3);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(const PlayerFinished(tick: 1, playerId: 'solo-player'));
      emit(const PlayerFinished(tick: 2, playerId: 'bot-1'));
      emit(const PlayerFinished(tick: 3, playerId: 'bot-2'));
      emit(const PlayerFinished(tick: 4, playerId: 'bot-3'));
    }
    super.tickInputs(inputs);
  }
}

void main() {
  late ProfileStore store;
  late FakeSfxPlayer player;
  late ShellResultsFlow flow;

  setUp(() async {
    store = ProfileStore(storage: FakeKeyValueStorage());
    await store.load();
    player = FakeSfxPlayer();
    flow = ShellResultsFlow(
      recorder: StatsRecorder(store: store),
      sound: SoundService(
        player: player,
        profile: ProfileController(store: store),
      ),
    );
  });

  /// Plays one scripted match (human wins) to ROUND_RESULTS.
  (ShellController, SoloMatchController) playMatch() {
    final shell = ShellController();
    final scheduler = FakeSoloScheduler();
    final solo = SoloMatchController(
      shell: shell,
      config: const SoloMatchConfig(matchSeed: 11),
      scheduler: scheduler.call,
      simulationFactory: (minigameId, mapSeed, roster) =>
          _HumanWinsSim(minigameId: minigameId, roster: roster),
    );
    addTearDown(solo.dispose);
    solo.startSolo();
    scheduler.elapse(3000);
    final session = solo.currentRound;
    expect(session, isNotNull, reason: 'round must be built on ROUND_PLAY');
    while (!session!.driver.isRoundOver) {
      session.driver.tick();
    }
    expect(shell.phase, RoundPhase.roundResults);
    return (shell, solo);
  }

  test('flow_records_stats_and_best_once_per_match', () {
    final (shell, solo) = playMatch();

    flow
      ..handle(shell: shell, solo: solo)
      ..handle(shell: shell, solo: solo);

    expect(store.stats.matchesPlayed, 1);
    expect(store.stats.bestRaceMs, 17);
  });

  test('flow_flags_new_best_on_first_completed_race', () {
    final (shell, solo) = playMatch();

    flow.handle(shell: shell, solo: solo);

    expect(flow.isNewBest, isTrue);
  });

  test('flow_no_new_best_without_a_finisher_time', () {
    final (shell, solo) = playMatch();

    // The human's finish time is what feeds the record (GDD § 8.1);
    // a null time (timeout-ranked) must never set one.
    flow.handle(shell: shell, solo: solo);

    expect(solo.humanFinishMs, isNotNull);
    expect(flow.isNewBest, isTrue);
  });

  test('flow_plays_fanfare_for_rank_one', () {
    final (shell, solo) = playMatch();

    flow.handle(shell: shell, solo: solo);

    expect(
      player.plays.map((p) => p.$1).toList(),
      containsAll(<String>['sfx/finish.ogg', 'sfx/fanfare.ogg']),
    );
  });

  test('flow_plays_quiet_fail_when_human_timed_out', () {
    // Timeout-ranked round: no PlayerFinished events at all; the
    // human trails the bots on progress (default static poses put
    // seat 0 rearmost), so they place last without finishing.
    final shell = ShellController();
    final scheduler = FakeSoloScheduler();
    final solo = SoloMatchController(
      shell: shell,
      config: const SoloMatchConfig(matchSeed: 2),
      scheduler: scheduler.call,
      simulationFactory: (minigameId, mapSeed, roster) => FakeSoloSim(
        minigameId: minigameId,
        roster: roster,
        completeAfterTicks: 15,
        progressAnchor: 0,
      ),
    );
    addTearDown(solo.dispose);
    solo.startSolo();
    scheduler.elapse(3000);
    final session = solo.currentRound;
    while (!session!.driver.isRoundOver) {
      session.driver.tick();
    }

    flow.handle(shell: shell, solo: solo);

    expect(player.plays, hasLength(1));
    expect(player.plays.single, ('sfx/fail.ogg', 0.5));
    expect(flow.isNewBest, isFalse);
  });

  test('flow_reset_allows_the_next_match_to_record', () {
    final (shell, solo) = playMatch();
    flow
      ..handle(shell: shell, solo: solo)
      ..reset();

    final (shell2, solo2) = playMatch();
    flow.handle(shell: shell2, solo: solo2);

    expect(store.stats.matchesPlayed, 2);
    // Equal time (17 ms again) does not beat the record.
    expect(flow.isNewBest, isFalse);
  });
}
