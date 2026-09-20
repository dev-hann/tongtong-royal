import 'package:app/infra/profile_store.dart';
import 'package:app/infra/sound_service.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:app/show/show_config.dart';
import 'package:app/show/show_controller.dart';
import 'package:app/show/show_outcome_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import '../infra/fake_key_value_storage.dart';
import '../infra/fake_sfx_player.dart';
import 'fake_show_scheduler.dart';
import 'fake_show_sim.dart';

/// R1: human finishes 1st (qualified, finish time recorded).
final class _R1HumanFirst extends FakeShowSim {
  _R1HumanFirst({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 2);

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

/// R2: one bot eliminated — quota closes with the human alive.
final class _R2EliminateLastBot extends FakeShowSim {
  _R2EliminateLastBot({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 2);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(PlayerEliminated(tick: 1, playerId: roster.last));
    }
    super.tickInputs(inputs);
  }
}

/// FINAL: the given player crosses first.
final class _FinalWonBy extends FakeShowSim {
  _FinalWonBy(
    this.champion, {
    required super.minigameId,
    required super.roster,
  }) : super(completeAfterTicks: 2);

  final PlayerId champion;

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(PlayerFinished(tick: 1, playerId: champion));
    }
    super.tickInputs(inputs);
  }
}

/// R1: the human finishes last — eliminated at the flash.
final class _R1HumanLast extends FakeShowSim {
  _R1HumanLast({required super.minigameId, required super.roster})
    : super(completeAfterTicks: 2);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (tickCount == 0) {
      emit(const PlayerFinished(tick: 1, playerId: 'bot-1'));
      emit(const PlayerFinished(tick: 2, playerId: 'bot-2'));
      emit(const PlayerFinished(tick: 3, playerId: 'bot-3'));
      emit(const PlayerFinished(tick: 4, playerId: 'solo-player'));
    }
    super.tickInputs(inputs);
  }
}

void main() {
  late FakeShowScheduler scheduler;
  late ProfileStore store;
  late StatsRecorder recorder;
  late FakeSfxPlayer sfx;
  late SoundService sound;
  late ShowResultsFlow flow;
  var championForFinal = 'solo-player';

  ShowController buildController() {
    final controller = ShowController(
      config: const ShowConfig(showSeed: 5),
      scheduler: scheduler.call,
      simulationFactory: (slot, mapSeed, roster) {
        final sim = switch (slot.roundIndex) {
          1 => _R1HumanFirst(minigameId: slot.gameId, roster: roster),
          2 => _R2EliminateLastBot(minigameId: slot.gameId, roster: roster),
          _ => _FinalWonBy(
            championForFinal,
            minigameId: slot.gameId,
            roster: roster,
          ),
        };
        return (simulation: sim, map: Object());
      },
      botBrainFactory:
        (gameId,
            {required isFinal,
            required mapSeed,
            required botIds,
            required map}) => const {},
    );
    controller.addListener(() => flow.handle(controller));
    return controller;
  }

  setUp(() async {
    scheduler = FakeShowScheduler();
    store = ProfileStore(storage: FakeKeyValueStorage());
    await store.load();
    recorder = StatsRecorder(store: store);
    sfx = FakeSfxPlayer();
    final profile = ProfileController(store: store);
    addTearDown(profile.dispose);
    sound = SoundService(player: sfx, profile: profile);
    flow = ShowResultsFlow(recorder: recorder, sound: sound);
    championForFinal = 'solo-player';
  });

  /// Runs the whole show to its terminal state, ticking every
  /// mounted round to completion.
  List<ShowPhase> runWholeShow(ShowController controller) {
    final phases = <ShowPhase>[];
    controller.addListener(() => phases.add(controller.phase));
    controller.startShow();
    while (true) {
      switch (controller.phase) {
        case ShowPhase.showIntro:
          scheduler.elapse(showIntroSeconds * 1000);
        case ShowPhase.roundPlay:
          final session = controller.currentRound!;
          while (!session.driver.isRoundOver) {
            session.driver.tick();
          }
        case ShowPhase.qualifyFlash:
          scheduler.elapse(qualifyFlashSeconds * 1000);
        case ShowPhase.podium:
        case ShowPhase.lobby:
          return phases;
      }
    }
  }

  test('crown_show_records_all_write_moments_exactly_once', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    runWholeShow(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, ShowPhase.podium);
    expect(store.stats.showsPlayed, 1);
    expect(store.stats.finalsReached, 1);
    expect(store.stats.crownsWon, 1);
    // Human finished R1 at tick 1 (60 Hz) — a finisher's best record.
    expect(store.stats.bestRaceMs, 17);

    // Replays of the same terminal state never double-write.
    flow.handle(controller);
    await Future<void>.delayed(Duration.zero);
    expect(store.stats.showsPlayed, 1);
    expect(store.stats.finalsReached, 1);
    expect(store.stats.crownsWon, 1);
  });

  test('lost_final_records_finals_and_show_but_no_crown', () async {
    championForFinal = 'bot-1';
    final controller = buildController();
    addTearDown(controller.dispose);

    runWholeShow(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, ShowPhase.podium);
    expect(store.stats.showsPlayed, 1);
    expect(store.stats.finalsReached, 1);
    expect(store.stats.crownsWon, 0);
  });

  test('eliminated_in_r1_records_show_once_at_summary_never_finals', () async {
    final controller = ShowController(
      config: const ShowConfig(showSeed: 5),
      scheduler: scheduler.call,
      simulationFactory: (slot, mapSeed, roster) {
        final sim = switch (slot.roundIndex) {
          1 => _R1HumanLast(minigameId: slot.gameId, roster: roster),
          _ => _R2EliminateLastBot(minigameId: slot.gameId, roster: roster),
        };
        return (simulation: sim, map: Object());
      },
      botBrainFactory:
        (gameId,
            {required isFinal,
            required mapSeed,
            required botIds,
            required map}) => const {},
    );
    controller.addListener(() => flow.handle(controller));
    addTearDown(controller.dispose);

    runWholeShow(controller);
    await Future<void>.delayed(Duration.zero);

    // GDD v2 § 7.3: the summary IS a show completion; the FINAL was
    // never started by the human.
    expect(controller.summary, isNotNull);
    expect(store.stats.showsPlayed, 1);
    expect(store.stats.finalsReached, 0);
    expect(store.stats.crownsWon, 0);
  });

  test('abandoned_show_records_nothing', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.startShow();
    scheduler.elapse(showIntroSeconds * 1000);
    controller.abandonShow();
    await Future<void>.delayed(Duration.zero);

    expect(store.stats.showsPlayed, 0);
    expect(store.stats.finalsReached, 0);
    expect(store.stats.crownsWon, 0);
    expect(store.stats.bestRaceMs, isNull);
  });

  test('crown_show_cues_finish_sting_then_fanfare_and_victory_loop', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    runWholeShow(controller);

    final paths = [for (final play in sfx.plays) play.$1];
    // R1 qualified → finish sting; FINAL crown → fanfare; PODIUM
    // ceremony → fanfare + victory loop (scope § 5 cue table).
    expect(paths, contains(Sfx.finish.assetPath));
    expect(paths.where((p) => p == Sfx.fanfare.assetPath).length, 2);
    expect(paths, contains(Sfx.victoryLoop.assetPath));
  });

  test('human_elimination_cues_fail_sting', () async {
    final controller = ShowController(
      config: const ShowConfig(showSeed: 5),
      scheduler: scheduler.call,
      simulationFactory: (slot, mapSeed, roster) {
        final sim = slot.roundIndex == 1
            ? _R1HumanLast(minigameId: slot.gameId, roster: roster)
            : _R2EliminateLastBot(minigameId: slot.gameId, roster: roster);
        return (simulation: sim, map: Object());
      },
      botBrainFactory:
        (gameId,
            {required isFinal,
            required mapSeed,
            required botIds,
            required map}) => const {},
    );
    controller.addListener(() => flow.handle(controller));
    addTearDown(controller.dispose);

    runWholeShow(controller);

    final paths = [for (final play in sfx.plays) play.$1];
    expect(paths, contains(Sfx.fail.assetPath));
    expect(paths, isNot(contains(Sfx.fanfare.assetPath)));
    expect(paths, isNot(contains(Sfx.victoryLoop.assetPath)));
  });
}
