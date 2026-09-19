import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

void main() {
  const registry = MinigameRegistry();

  test('pool_contains_trap_race', () {
    expect(registry.pool, contains('trap_race'));
  });

  test('by_id_returns_minigame_for_registered_id', () {
    expect(registry.byId('trap_race'), isA<TrapRace>());
  });

  test('by_id_throws_argument_error_for_unknown_id', () {
    expect(() => registry.byId('no_such_game'), throwsArgumentError);
  });

  test('pool_contains_every_builtin_game', () {
    expect(registry.pool, containsAll(<String>['trap_race', 'hammer_dodge']));
  });

  test('pool_is_exactly_the_two_mvp_games', () {
    expect(registry.pool, ['trap_race', 'hammer_dodge']);
  });

  test('registry_looks_up_injected_games', () {
    const custom = MinigameRegistry([_FakeGame()]);

    expect(custom.pool, ['fake_game']);
    expect(custom.byId('fake_game'), isA<_FakeGame>());
    expect(custom.pool, isNot(contains('trap_race')));
  });
}

final class _FakeGame implements MiniGame {
  const _FakeGame();

  @override
  MiniGameId get id => 'fake_game';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Fake',
    oneLineRule: 'Fake rule.',
    timeoutMs: 1_000,
  );

  @override
  RoundResult resolve(RoundEvents events) => RoundResult(
    roundIndex: events.roundIndex,
    minigameId: id,
    placements: const [],
  );
}
