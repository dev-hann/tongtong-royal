import 'package:tongtong_shared/src/domain/models.dart';

/// A raw simulation event of one round, in emission order.
sealed class RoundEvent {
  const RoundEvent();
}

/// A player crossed the finish line at [tick] (race archetype).
final class PlayerFinished extends RoundEvent {
  /// Creates the event.
  const PlayerFinished({required this.tick, required this.playerId});

  /// Simulation tick of the finish. Same tick means a shared rank
  /// (GDD § 7.6).
  final int tick;

  /// The player who finished.
  final PlayerId playerId;
}

/// A player entered a fall zone at [tick] (host respawns at checkpoint).
final class PlayerFell extends RoundEvent {
  /// Creates the event.
  const PlayerFell({required this.tick, required this.playerId});

  /// Simulation tick of the fall.
  final int tick;

  /// The player who fell.
  final PlayerId playerId;
}

/// A player was eliminated at [tick] (survival archetype).
final class PlayerEliminated extends RoundEvent {
  /// Creates the event.
  const PlayerEliminated({required this.tick, required this.playerId});

  /// Simulation tick of the elimination. Same-tick eliminations form a
  /// shared rank (GDD § 7.7).
  final int tick;

  /// The player who was eliminated.
  final PlayerId playerId;
}

/// A hold-time accumulation sample (occupancy archetype, GDD § 4.3).
final class HoldTimeSample extends RoundEvent {
  /// Creates the event.
  const HoldTimeSample({required this.playerId, required this.seconds});

  /// The player who was holding the crown zone.
  final PlayerId playerId;

  /// Accumulated hold time in seconds at sampling time.
  final double seconds;
}

/// Ordered raw events of one round, plus the round the events belong to.
///
/// v2 event channel (arch § 3): the show-level judgment context —
/// [quota], [isFinal], [roster] — travels on the events so every
/// resolver receives it through one input. All three default to
/// legacy values, keeping v1 `resolve` call sites valid.
final class RoundEvents {
  /// Creates the event log for round [roundIndex].
  const RoundEvents({
    required this.roundIndex,
    this.events = const [],
    this.quota,
    this.isFinal = false,
    this.roster = const {},
  });

  /// Zero-based index of the round inside the match.
  final int roundIndex;

  /// Events in emission (simulation) order.
  final List<RoundEvent> events;

  /// Qualification quota of this round (GDD § 4); null on v1
  /// placement-era calls.
  final int? quota;

  /// Whether this round is the FINAL (crown round, GDD § 4).
  final bool isFinal;

  /// Players fielded into this round, including players that emit
  /// no events at all (idle bodies).
  final Set<PlayerId> roster;

  /// Distinct players mentioned by the events, in first-appearance order.
  List<PlayerId> get players {
    final seen = <PlayerId>{};
    return [
      for (final event in events)
        switch (event) {
          PlayerFinished(:final playerId) when seen.add(playerId) =>
            playerId,
          PlayerFell(:final playerId) when seen.add(playerId) => playerId,
          PlayerEliminated(:final playerId) when seen.add(playerId) =>
            playerId,
          HoldTimeSample(:final playerId) when seen.add(playerId) =>
            playerId,
          _ => null,
        },
    ].whereType<PlayerId>().toList();
  }
}

/// Metadata for UI (GDD § 5 intro screen, timeouts in § 4).
final class MiniGameSpec {
  /// Creates the spec.
  const MiniGameSpec({
    required this.name,
    required this.oneLineRule,
    required this.timeoutMs,
  });

  /// Display name shown on the intro screen.
  final String name;

  /// One-line rule shown on the intro screen.
  final String oneLineRule;

  /// Round timeout in milliseconds.
  final int timeoutMs;
}

/// Domain-level minigame contract (docs/02-architecture.md § 3).
///
/// Implementations resolve placements from raw round events; they never
/// touch physics, rendering, or I/O.
abstract interface class MiniGame {
  /// Identity of this minigame.
  MiniGameId get id;

  /// Given the ordered events of one round, produce its placements.
  RoundResult resolve(RoundEvents events);

  /// Metadata for UI.
  MiniGameSpec get spec;
}
