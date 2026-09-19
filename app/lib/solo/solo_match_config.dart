import 'dart:math' as math;

import 'package:tongtong_shared/tongtong_shared.dart';

/// One planned round: which minigame runs and which seed builds its
/// map variant (GDD § 6: the seed is host-chosen and everyone builds
/// the same map from it).
typedef SoloRoundPlan = ({MiniGameId minigameId, int mapSeed});

/// Configuration of a solo match: one human seat plus bot fill (GDD
/// § 9.1), the round count, and the seed family all randomness
/// derives from. Pure data — no rules here.
final class SoloMatchConfig {
  /// Creates a config.
  const SoloMatchConfig({
    this.humanId = 'solo-player',
    this.humanNickname = 'You',
    this.humanColorIndex = 0,
    this.rounds = MatchRules.roundCount,
    this.matchSeed = 0,
  });

  /// Player id of the human seat.
  final PlayerId humanId;

  /// Lobby nickname of the human seat.
  final String humanNickname;

  /// PlayerPalette index (0..3) of the human seat's color
  /// (GDD § 8.1 persisted profile color; injected by the shell
  /// wiring, the controller never reads storage).
  final int humanColorIndex;

  /// Rounds per match (GDD § 2: one).
  final int rounds;

  /// Root seed of the match; every map seed derives from it, so a
  /// seed replays a whole match deterministically.
  final int matchSeed;
}

/// Large odd mixer so plan generations never reuse an rng stream.
const int _generationStride = 1000003;

/// Offset keeping the map-seed rng streams of generations apart.
const int _mapSeedStreamOffset = 987654321;

/// Plans the rounds of one solo match (GDD § 6: no selection rule —
/// the pool is dealt in registration order) with each round's map
/// seed from a dedicated rng stream keyed by `(matchSeed,
/// generation)` — a replay (higher [generation]) replans with fresh
/// seeds from the same match seed family.
List<SoloRoundPlan> planSoloRounds({
  required int rounds,
  required List<MiniGameId> pool,
  required int matchSeed,
  required int generation,
}) {
  if (pool.isEmpty) {
    throw ArgumentError.value(pool, 'pool', 'must not be empty');
  }
  if (rounds < 0) {
    throw ArgumentError.value(rounds, 'rounds', 'must not be negative');
  }
  final games = [for (var i = 0; i < rounds; i++) pool[i % pool.length]];
  final rng = math.Random(
    matchSeed + _mapSeedStreamOffset + generation * _generationStride,
  );
  return [
    for (final minigameId in games)
      (minigameId: minigameId, mapSeed: rng.nextInt(1 << 31)),
  ];
}
