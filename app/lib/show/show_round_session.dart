import 'package:app/game/round_simulation.dart';
import 'package:app/show/show_round_driver.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// One playable round handed to the play view: simulation, driver,
/// map data and seat identities. Judging stays inside the driver's
/// domain resolve; this record is pure plumbing.
final class ShowRoundSession {
  /// Creates the session.
  const ShowRoundSession({
    required this.driver,
    required this.simulation,
    required this.map,
    required this.minigameId,
    required this.isFinal,
    required this.humanId,
    required this.rosterIds,
  });

  /// Per-tick glue over [simulation] (human + bot inputs, events,
  /// samples, completion).
  final ShowRoundDriver driver;

  /// The round's simulation.
  final RoundSimulation simulation;

  /// Map data the simulation was built from (renderer + bot maps).
  final Object map;

  /// Minigame id of the round.
  final MiniGameId minigameId;

  /// Whether this round is the FINAL (crown round).
  final bool isFinal;

  /// The human seat; null in headless rounds.
  final PlayerId? humanId;

  /// All seats, human first then bots.
  final List<PlayerId> rosterIds;

  /// Whether the round already ended.
  bool get isOver => driver.isRoundOver;
}
