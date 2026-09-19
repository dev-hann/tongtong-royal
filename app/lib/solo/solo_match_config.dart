import 'dart:math' as math;

import 'package:tongtong_shared/tongtong_shared.dart';

/// One planned round: which minigame runs and which seed builds its
/// map variant (GDD § 6: the seed is host-chosen and everyone builds
/// the same map from it).
typedef SoloRoundPlan = ({MiniGameId minigameId, int mapSeed});

/// Configuration of a solo match: one human seat plus bot fill (GDD
/// § 9.1), a fixed round count, and the seed family all randomness
/// derives from. Pure data — no rules here.
final class SoloMatchConfig {
  /// Creates a config.
  const SoloMatchConfig({
    this.humanId = 'solo-player',
    this.humanNickname = 'You',
    this.rounds = MatchRules.roundCount,
    this.matchSeed = 0,
  });

  /// Player id of the human seat.
  final PlayerId humanId;

  /// Lobby nickname of the human seat.
  final String humanNickname;

  /// Rounds per match (GDD § 2: 3).
  final int rounds;

  /// Root seed of the match; every shuffle and map seed derives from
  /// it, so a seed replays a whole match deterministically.
  final int matchSeed;
}

/// Large odd mixer so plan generations never reuse an rng stream.
const int _generationStride = 1000003;

/// Offset keeping the selector seed and the map-seed seed apart.
const int _mapSeedStreamOffset = 987654321;

/// Plans the rounds of one solo match: minigames come from
/// [MinigameSelector.planMatch] (GDD § 6 shuffled cycle) and each
/// round's map seed from a dedicated rng stream, both keyed by
/// `(matchSeed, generation)` — a rematch (higher [generation]) replans
/// with fresh seeds from the same match seed family.
List<SoloRoundPlan> planSoloRounds({
  required int rounds,
  required List<MiniGameId> pool,
  required int matchSeed,
  required int generation,
}) {
  final games = MinigameSelector.planMatch(
    rounds,
    pool,
    matchSeed + generation * _generationStride,
  );
  final rng = math.Random(
    matchSeed + _mapSeedStreamOffset + generation * _generationStride,
  );
  return [
    for (final minigameId in games)
      (minigameId: minigameId, mapSeed: rng.nextInt(1 << 31)),
  ];
}
