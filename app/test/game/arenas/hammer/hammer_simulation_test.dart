import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless arena fixtures: fixed-dt stepping only, no wall clock
/// (testing doc § 4). Generous tick budgets keep the tests robust
/// against solver jitter without timing assertions.
const int _maxTicks = 2400;

/// 30 s in ticks (shrink start boundary).
const int _shrinkStartTick = 30 * PhysicsConsts.tickRate;

/// 45 s in ticks (shrink end boundary).
const int _shrinkEndTick = 45 * PhysicsConsts.tickRate;

PlayerInputState _idle() => PlayerInputState();

PlayerInputState _right() => PlayerInputState(moveDir: Vector2(1, 0));

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

/// Arena without mallets (same geometry): eliminations there must
/// be rim falls, never arm hits.
HammerArenaMap _hammerlessMap() {
  final base = HammerArenaMap.hammerArena(7);
  return HammerArenaMap(
    mapSeed: base.mapSeed,
    platformRadius: base.platformRadius,
    platformSegmentCount: base.platformSegmentCount,
    platformThickness: base.platformThickness,
    killRingMargin: base.killRingMargin,
    shrink: base.shrink,
    centerSlab: base.centerSlab,
    spawnPoints: base.spawnPoints,
    hammers: const [],
  );
}

void main() {
  group('HammerSimulation', () {
    test('default_timeout_ticks_derive_from_60s_spec', () {
      expect(HammerSimulation.defaultTimeoutTicks, 60 * PhysicsConsts.tickRate);
    });

    test('idle_spawns_survive_five_seconds', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2', 'p3'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (var i = 0; i < 5 * PhysicsConsts.tickRate; i++) {
        sim.tickInputs({
          'p1': _idle(),
          'p2': _idle(),
          'p3': _idle(),
        });
      }

      expect(sim.survivorIds, hasLength(3));
      expect(events, isEmpty);
      expect(sim.isComplete, isFalse);
    });

    test('center_drift_pulls_a_spawned_player_inward', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );
      final startX = sim.bodyOf('p1').position.x;

      for (var i = 0; i < 120; i++) {
        sim.tickInputs({'p1': _right()});
      }

      expect(
        sim.bodyOf('p1').position.x,
        greaterThan(startX),
        reason: 'right input walks the leftmost spawn toward center',
      );
      expect(sim.isAlive('p1'), isTrue);
    });

    test('mallet_head_sweep_eliminates_on_contact', () {
      final sim = HammerSimulation(
        map: HammerArenaMap.hammerArena(7),
        playerIds: const ['p1'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Park the player on the upper slope, whose body dips into
      // both mallet bands: a head must reach them within two arm
      // revolutions.
      sim.bodyOf('p1').setTransform(Vector2(5.3, 5.3), 0);

      _runUntil(sim, {'p1': _idle()}, () => !sim.isAlive('p1'));

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(1));
      expect(eliminations.single.playerId, 'p1');
      expect(() => sim.bodyOf('p1'), throwsStateError);
    });

    test('shrink_holds_tiers_until_30s_then_drops_stepwise', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );

      for (var i = 0; i < _shrinkStartTick; i++) {
        sim.tickInputs({'p1': _idle()});
      }

      expect(sim.currentShrinkRadius, closeTo(7, 1e-9));
      expect(sim.activeTierCount, 5);

      sim.tickInputs({'p1': _idle()});

      expect(sim.currentShrinkRadius, lessThan(7));
      expect(sim.activeTierCount, 4);
    });

    test('shrink_settles_at_4_5m_with_one_tier_left', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );

      for (var i = 0; i < _shrinkEndTick; i++) {
        sim.tickInputs({'p1': _idle()});
      }

      expect(sim.currentShrinkRadius, closeTo(4.5, 1e-9));
      expect(sim.activeTierCount, 1);
      expect(sim.isAlive('p1'), isTrue, reason: 'slab spawn survives shrink');
    });

    test('off_shrunk_rim_position_eliminates_after_full_shrink', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (var i = 0; i < _shrinkEndTick; i++) {
        sim.tickInputs({'p1': _idle()});
      }

      sim.bodyOf('p1').setTransform(Vector2(6, 0), 0);
      sim.tickInputs({'p1': _idle()});

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(1));
      expect(eliminations.single.playerId, 'p1');
      expect(sim.isComplete, isTrue);
    });

    test('quota_completion_ends_the_round_instantly', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2', 'p3'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(
        Vector2(0, -(sim.map.initialKillRadius + 3)),
        0,
      );
      sim.tickInputs({'p1': _idle(), 'p2': _idle(), 'p3': _idle()});

      expect(sim.isComplete, isTrue);
      expect(events.whereType<PlayerEliminated>(), hasLength(1));

      sim.tickInputs({'p1': _idle(), 'p2': _idle(), 'p3': _idle()});

      expect(events.whereType<PlayerEliminated>(), hasLength(1));
    });

    test('same_tick_double_elimination_crossing_quota_completes', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2', 'p3'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      sim.bodyOf('p1').setTransform(
        Vector2(0, -(sim.map.initialKillRadius + 3)),
        0,
      );
      sim.bodyOf('p2').setTransform(
        Vector2(sim.map.initialKillRadius + 3, 0),
        0,
      );
      sim.tickInputs({
        'p1': _idle(),
        'p2': _idle(),
        'p3': _idle(),
      });

      final eliminations = events.whereType<PlayerEliminated>().toList();
      expect(eliminations, hasLength(2));
      expect(eliminations.first.tick, equals(eliminations.last.tick));
      expect(sim.survivorIds, ['p3']);
      expect(sim.isComplete, isTrue);
    });

    test('timeout_with_all_alive_completes_the_round', () {
      final sim = HammerSimulation.forTesting(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2', 'p3'],
        quota: 2,
        timeoutTicks: 120,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      for (var i = 0; i < 120; i++) {
        sim.tickInputs({'p1': _idle(), 'p2': _idle(), 'p3': _idle()});
      }

      expect(sim.isComplete, isTrue);
      expect(sim.survivorIds, hasLength(3));
      expect(events, isEmpty);
    });

    test('four_starters_run_the_quota_round', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2', 'p3', 'p4'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);
      final inputs = {
        'p1': _idle(),
        'p2': _idle(),
        'p3': _idle(),
        'p4': _idle(),
      };

      sim.bodyOf('p4').setTransform(
        Vector2(0, -(sim.map.initialKillRadius + 3)),
        0,
      );
      sim.tickInputs(inputs);
      expect(sim.isComplete, isFalse, reason: '4 -> 3 alive is above quota');

      sim.bodyOf('p3').setTransform(
        Vector2(sim.map.initialKillRadius + 3, 0),
        0,
      );
      sim.tickInputs(inputs);

      expect(events.whereType<PlayerEliminated>(), hasLength(2));
      expect(sim.survivorIds, ['p1', 'p2']);
      expect(sim.isComplete, isTrue);
    });

    test('duplicate_elimination_signals_emit_one_event', () {
      final sim = HammerSimulation(
        map: HammerArenaMap.hammerArena(7),
        playerIds: const ['p1'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Beyond both the kill ring and the radial guard: whichever
      // fires first wins, exactly once.
      sim.bodyOf('p1').setTransform(
        Vector2(0, -(sim.map.initialKillRadius + 30)),
        0,
      );
      sim.tickInputs({'p1': _idle()});

      expect(events.whereType<PlayerEliminated>(), hasLength(1));
    });

    test('poseOf_returns_null_for_eliminated_players', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1', 'p2'],
        quota: 2,
      );

      sim.bodyOf('p1').setTransform(
        Vector2(0, -(sim.map.initialKillRadius + 3)),
        0,
      );
      sim.tickInputs({'p1': _idle(), 'p2': _idle()});

      expect(sim.poseOf('p1'), isNull);
      expect(sim.poseOf('p2'), isNotNull);
    });

    test('progressAnchorX_is_null_for_arenas', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );

      expect(sim.progressAnchorX, isNull);
    });

    test('walking_off_the_rim_eliminates_the_runner', () {
      final sim = HammerSimulation(
        map: _hammerlessMap(),
        playerIds: const ['p1'],
        quota: 2,
      );
      final events = <RoundEvent>[];
      sim.events.listen(events.add);

      // Start from the top step and push outward.
      sim.bodyOf('p1').setTransform(Vector2(0.5, 7.8), 0);
      _runUntil(sim, {'p1': _right()}, () => !sim.isAlive('p1'));

      expect(events.whereType<PlayerEliminated>(), hasLength(1));
    });
  });
}
