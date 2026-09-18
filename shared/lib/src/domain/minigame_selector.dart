import 'dart:math';

import 'package:tongtong_shared/src/domain/models.dart';

/// Minigame selection for a match (GDD § 6).
abstract final class MinigameSelector {
  /// Plans the minigame sequence for a match of [rounds] rounds drawn from
  /// [pool], deterministically from [seed].
  ///
  /// Shuffled cycle: shuffle the full pool, deal rounds from it, reshuffle
  /// when exhausted; the first game of a new cycle never equals the last
  /// game of the previous cycle. Pools with a single game repeat it.
  static List<MiniGameId> planMatch(
    int rounds,
    List<MiniGameId> pool,
    int seed,
  ) {
    if (pool.isEmpty) {
      throw ArgumentError.value(pool, 'pool', 'must not be empty');
    }
    if (pool.toSet().length != pool.length) {
      throw ArgumentError.value(pool, 'pool', 'must contain unique games');
    }
    if (rounds < 0) {
      throw ArgumentError.value(rounds, 'rounds', 'must not be negative');
    }

    final rng = Random(seed);
    final deck = List<MiniGameId>.of(pool)..shuffle(rng);

    final plan = <MiniGameId>[];
    MiniGameId? lastDealt;
    var position = 0;
    for (var i = 0; i < rounds; i++) {
      if (position == deck.length) {
        deck.shuffle(rng);
        if (deck.length > 1 && deck.first == lastDealt) {
          deck.setAll(0, [deck[1], deck[0], ...deck.skip(2)]);
        }
        position = 0;
      }
      lastDealt = deck[position];
      plan.add(lastDealt);
      position++;
    }
    return plan;
  }
}
