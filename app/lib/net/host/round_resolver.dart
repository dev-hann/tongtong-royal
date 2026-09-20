import 'package:tongtong_shared/tongtong_shared.dart';

/// Round data the host runtime collects during a round, handed to
/// the domain resolver alongside the ordered events. Pure plumbing
/// carrier — every rule lives in the domain game (architecture doc
/// § 2).
final class RoundData {
  /// Creates the carrier.
  const RoundData({required this.roster, this.progressSamples = const []});

  /// Every seat for the round, including players that emitted no
  /// events (idle bodies, GDD § 7.2).
  final Set<PlayerId> roster;

  /// Forward-progress samples (race archetype only; collected by the
  /// host every [PhysicsConsts.progressSampleIntervalTicks] ticks).
  final List<ProgressSample> progressSamples;
}

/// Resolves one finished round through [game]'s domain rules by
/// packing the game's typed resolve input from [data]. This is
/// game-layer glue, not judging: it only routes already-collected
/// raw data into each minigame's `resolve(events, input)` overload
/// (the optional input parameter is per-game, so it cannot be
/// called through the `MiniGame` base type).
///
/// Adding a minigame archetype means adding one case here plus one
/// simulation factory case; adding a course variant of an existing
/// archetype stays pure map data (M4 DoD).
RoundResult resolveRound(MiniGame game, RoundEvents events, RoundData data) {
  switch (game) {
    case final TrapRace race:
      return race.resolve(
        events,
        TrapRaceInput(roster: data.roster, samples: data.progressSamples),
      );
    default:
      throw ArgumentError.value(game.id, 'game', 'no resolve input binding');
  }
}

/// v2 qualification glue (architecture doc § 3, GDD v2): resolves
/// one finished round's qualification verdict through the game's
/// `resolveQualification`, packing the same typed inputs as
/// [resolveRound]. The quota, FINAL flag and roster travel on
/// [RoundEvents]; the future show runtime supplies them. v1
/// placements keep flowing through [resolveRound] unchanged.
QualificationResult resolveQualificationRound(
  MiniGame game,
  RoundEvents events,
  RoundData data,
) {
  switch (game) {
    case final TrapRace race:
      return race.resolveQualification(
        events,
        TrapRaceInput(roster: data.roster, samples: data.progressSamples),
      );
    case final HammerDodge hammer:
      return hammer.resolveQualification(
        events,
        HammerDodgeInput(roster: data.roster),
      );
    default:
      throw ArgumentError.value(
        game.id,
        'game',
        'no qualification resolve binding',
      );
  }
}
