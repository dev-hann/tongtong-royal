import 'package:app/show/show_config.dart';
import 'package:app/show/show_round_driver.dart';
import 'package:app/show/show_round_session.dart';
import 'package:app/show/show_simulation_factory.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Builds one round's live or headless session from the schedule
/// slot, the derived map seed and the starter field (GDD v2 § 4/§ 6).
/// Pure wiring: rules stay in the domain resolve, brains come from
/// the injected factory. Kept beside the controller so the flow file
/// stays within the repo line limit (docs/05 § 2).
ShowRoundSession buildShowRoundSession({
  required ShowConfig config,
  required MinigameRegistry registry,
  required ShowSimulationFactory simulationFactory,
  required ShowBotBrainFactory botBrainFactory,
  required ShowSlot slot,
  required int roundIndex,
  required int mapSeed,
  required List<PlayerId> starters,
  required void Function(QualificationResult result) onRoundComplete,
  bool live = true,
}) {
  final bundle = simulationFactory(slot, mapSeed, starters);
  final botIds = [
    for (final id in starters)
      if (id != config.humanId) id,
  ];
  final brains = botBrainFactory(
    slot.gameId,
    isFinal: slot.isFinal,
    mapSeed: mapSeed,
    botIds: botIds,
    map: bundle.map,
  );
  final driver = ShowRoundDriver(
    simulation: bundle.simulation,
    game: registry.byId(slot.gameId),
    roundIndexZeroBased: roundIndex - 1,
    quota: slot.quota,
    isFinal: slot.isFinal,
    roster: starters.toSet(),
    humanId: starters.contains(config.humanId) ? config.humanId : null,
    brains: brains,
    map: bundle.map,
    onRoundComplete: onRoundComplete,
  );
  return ShowRoundSession(
    driver: driver,
    simulation: bundle.simulation,
    map: bundle.map,
    minigameId: slot.gameId,
    isFinal: slot.isFinal,
    humanId: driver.humanId,
    rosterIds: starters,
  );
}

/// Runs rounds `fromRound`..FINAL headlessly (GDD v2 § 7.3): real
/// simulations, fixed dt, bots only, the show's seed chain
/// continuing (`mapSeed = stream(showSeed, roundIndex)`). Returns
/// the simulated champions.
List<PlayerId> resolveHeadlessShow({
  required ShowConfig config,
  required ShowSchedule schedule,
  required MinigameRegistry registry,
  required ShowSimulationFactory simulationFactory,
  required ShowBotBrainFactory botBrainFactory,
  required List<PlayerId> field,
  required int fromRound,
  required int showSeed,
}) {
  var starters = List<PlayerId>.of(field);
  for (var roundIndex = fromRound;
      roundIndex <= ShowSchedule.roundCount;
      roundIndex++) {
    final slot = schedule.slotFor(roundIndex);
    final mapSeed = ShowSchedule.mapSeedFor(
      showSeed: showSeed,
      roundIndex: roundIndex,
    );
    final session = buildShowRoundSession(
      config: config,
      registry: registry,
      simulationFactory: simulationFactory,
      botBrainFactory: botBrainFactory,
      slot: slot,
      roundIndex: roundIndex,
      mapSeed: mapSeed,
      starters: starters,
      onRoundComplete: (_) {},
      live: false,
    );
    final driver = session.driver;
    while (!driver.isRoundOver) {
      driver.tick();
    }
    driver.dispose();
    final verdict = driver.finish();
    if (verdict.isFinal) {
      return verdict.champions;
    }
    starters = List<PlayerId>.of(verdict.qualified);
  }
  throw StateError('headless show resolved without a FINAL');
}
