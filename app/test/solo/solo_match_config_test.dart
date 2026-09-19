import 'package:app/solo/solo_match_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  const pool = ['trap_race', 'hammer_dodge'];

  test('default config seats the human named You', () {
    const config = SoloMatchConfig();
    expect(config.humanId, 'solo-player');
    expect(config.humanNickname, 'You');
    expect(config.rounds, MatchRules.roundCount);
  });

  test('config carries the human nickname and color index', () {
    const config = SoloMatchConfig(humanNickname: 'HANN', humanColorIndex: 2);
    expect(config.humanNickname, 'HANN');
    expect(config.humanColorIndex, 2);
    expect(const SoloMatchConfig().humanColorIndex, 0);
  });

  test('plan is deterministic for the same seed and generation', () {
    final a = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 42,
      generation: 0,
    );
    final b = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 42,
      generation: 0,
    );
    expect(a, equals(b));
  });

  test('plan draws every round from the pool', () {
    final plan = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 7,
      generation: 0,
    );
    expect(plan, hasLength(3));
    for (final round in plan) {
      expect(pool, contains(round.minigameId));
      expect(round.mapSeed, greaterThanOrEqualTo(0));
    }
  });

  test('a later generation re-plans with fresh map seeds', () {
    final first = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 7,
      generation: 0,
    );
    final second = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 7,
      generation: 1,
    );
    // Same seed family, but the rematch must regenerate the plan —
    // at least the map seeds differ.
    final firstSeeds = first.map((r) => r.mapSeed).toList();
    final secondSeeds = second.map((r) => r.mapSeed).toList();
    expect(firstSeeds, isNot(equals(secondSeeds)));
  });

  test('different match seeds plan different matches', () {
    final a = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 1,
      generation: 0,
    );
    final b = planSoloRounds(
      rounds: 3,
      pool: pool,
      matchSeed: 2,
      generation: 0,
    );
    expect(a, isNot(equals(b)));
  });
}
