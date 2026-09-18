import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless arena fixtures: fixed-dt stepping only, no wall clock
/// (testing doc § 4). Generous tick budgets keep the tests robust
/// against solver jitter without timing assertions.
const int _maxTicks = 500;

PlayerInputState _right() => PlayerInputState(moveDir: Vector2(1, 0));
PlayerInputState _idle() => PlayerInputState();

/// Deterministic arena: same geometry as the factory variant but
/// without hammer arms (their knockback is covered by the builder
/// rotation tests; here eliminations must be input-driven).
HammerArenaMap _hammerlessMap() {
  final base = HammerArenaMap.hammerArena(7);
  return HammerArenaMap(
    mapSeed: base.mapSeed,
    platformRadius: base.platformRadius,
    platformSegmentCount: base.platformSegmentCount,
    platformThickness: base.platformThickness,
    killRadius: base.killRadius,
    spawnPoints: base.spawnPoints,
    hammers: const [],
  );
}

/// Runs [sim] with [inputs] until [isDone] holds after a tick.
/// Fails the test if it never holds within [_maxTicks].
void _runUntil(
  HammerSimulation sim,
  Map<String, PlayerInputState> inputs,
  bool Function() isDone,
) {
  for (var i = 0; i < _maxTicks; i++) {
    sim.tickInputs(inputs);
    if (isDone()) {
      return;
    }
  }
  fail('condition never met within $_maxTicks ticks');
}

Vector2 _farOutside(HammerArenaMap map) =>
    Vector2(0, -(map.killRadius + 3));

void main() {
  group('HammerSimulation', () {
    test('default_timeout_ticks_derive_from_gdd_4_2', () {
      expect(HammerSimulation.defaultTimeoutTicks, 60 * 60);
    });

    test('player walking off the arena is eliminated and the body is '
        'gone', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: ['p1'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Spawn slot 0 sits on the upper-right arc; running right walks
      // the player down the slope, off the equator and out of the
      // kill radius.
      _runUntil(sim, {'p1': _right()}, () => !sim.isAlive('p1'));

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(1));
      expect(eliminations.single.playerId, 'p1');
      expect(eliminations.single.tick, greaterThan(0));
      expect(sim.isAlive('p1'), isFalse);
      expect(() => sim.bodyOf('p1'), throwsStateError);
      expect(sim.isComplete, isTrue);
      expect(sim.winnerId, isNull);
    });

    test('two players out on the same tick share the elimination tick',
        () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(_farOutside(sim.map), 0);
      sim.bodyOf('p2').setTransform(
        Vector2(sim.map.killRadius + 3, 0),
        0,
      );
      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(2));
      expect(
        eliminations.first.tick,
        equals(eliminations.last.tick),
      );
      expect(
        eliminations.map((e) => e.playerId).toSet(),
        {'p1', 'p2'},
      );
      expect(sim.isComplete, isTrue);
      expect(sim.survivorIds, isEmpty);
      expect(sim.winnerId, isNull);
    });

    test('last player remaining completes the round as winner', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: ['p1', 'p2'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(_farOutside(sim.map), 0);
      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      expect(sim.isComplete, isTrue);
      expect(sim.survivorIds, ['p2']);
      expect(sim.winnerId, 'p2');
      expect(sim.isAlive('p2'), isTrue);
    });

    test('idle player on the static platform survives 100 ticks', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: ['p1'],
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (var i = 0; i < 100; i++) {
        sim.tick('p1', _idle());
      }

      expect(sim.isAlive('p1'), isTrue);
      expect(events, isEmpty);
      expect(sim.isComplete, isFalse);
      // The spawn slot sits on a 22.5-degree face, so the body
      // settles a little downslope before friction holds it; it
      // must stay well inside the kill radius the whole time.
      final spawn = sim.map.spawnPoints.first;
      final position = sim.bodyOf('p1').position;
      expect(position.x, closeTo(spawn.x, 1));
      expect(position.y, closeTo(spawn.y, 1));
      expect(position.length, lessThan(sim.map.killRadius - 0.5));
    });

    test('timeout completes the round with every survivor ranked',
        () {
      final sim = HammerSimulation.forTesting(
        map: _hammerlessMap(),
        playerIds: ['p1', 'p2'],
        timeoutTicks: 10,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (var i = 0; i < 9; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle()});
      }
      expect(sim.isComplete, isFalse);

      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      expect(sim.isComplete, isTrue);
      expect(sim.survivorIds, ['p1', 'p2']);
      expect(sim.winnerId, isNull);
      expect(events.whereType<PlayerEliminated>(), isEmpty);
    });
  });
}
