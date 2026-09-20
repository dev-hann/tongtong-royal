import 'dart:math' as math;

import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  group('HammerArenaMap.hammerArena', () {
    test('same_seed_produces_identical_arena_data', () {
      final a = HammerArenaMap.hammerArena(42);
      final b = HammerArenaMap.hammerArena(42);

      expect(a, equals(b));
      expect(a.toJson(), equals(b.toJson()));
    });

    test('different_seed_jitters_hammer_phases', () {
      final a = HammerArenaMap.hammerArena(7).hammers;
      final b = HammerArenaMap.hammerArena(8).hammers;

      expect(
        a.map((h) => h.initialAngle).toList(),
        isNot(equals(b.map((h) => h.initialAngle).toList())),
      );
    });

    test('json_roundtrip_preserves_the_map', () {
      for (final seed in [0, 7, 42]) {
        final map = HammerArenaMap.hammerArena(seed);

        final restored = HammerArenaMap.fromJson(map.toJson());

        expect(restored, equals(map), reason: 'seed $seed');
      }
    });

    test('fromJson_rejects_missing_fields', () {
      expect(
        () => HammerArenaMap.fromJson(const {'mapSeed': 1}),
        throwsFormatException,
      );
    });

    test('factory_matches_game_doc_spec', () {
      final map = HammerArenaMap.hammerArena(3);

      expect(map.platformRadius, 7);
      expect(map.platformSegmentCount, 16);
      expect(
        map.platformThickness,
        greaterThanOrEqualTo(PhysicsConsts.minWallThickness),
      );
      // Shrink phase: 30 s start, 15 s duration, 7 -> 4.5 m.
      expect(map.shrink.startSeconds, 30);
      expect(map.shrink.durationSeconds, 15);
      expect(map.shrink.endRadius, 4.5);
      expect(map.shrink.tierRadii(map.platformRadius).first, 7);
      expect(map.shrink.tierRadii(map.platformRadius).last, 4.5);
      // Kill ring: platform radius + half player + margin.
      expect(
        map.killRadiusFor(map.platformRadius),
        closeTo(
          map.platformRadius + PlayerCharacter.heightMeters / 2 + 0.5,
          1e-9,
        ),
      );
      expect(map.hammers, hasLength(2));
      // Counter-rotating mallet heads at the 7.1 / 6.9 m bands.
      expect(map.hammers[0].radius, closeTo(7.1, 1e-9));
      expect(map.hammers[0].angularSpeed, greaterThan(0));
      expect(map.hammers[1].radius, closeTo(6.9, 1e-9));
      expect(map.hammers[1].angularSpeed, lessThan(0));
      for (final hammer in map.hammers) {
        expect(hammer.headLength, isNotNull);
        expect(hammer.pivot.x, 0);
        expect(hammer.pivot.y, 0);
      }
    });

    test('hammer_speeds_stay_within_seed_jitter_bounds', () {
      const jitter = 0.25;
      const innerBase = 1.2;
      const outerBase = 1.7;
      for (final seed in [0, 1, 7, 42, 99]) {
        final hammers = HammerArenaMap.hammerArena(seed).hammers;
        expect(
          hammers[0].angularSpeed,
          inInclusiveRange(innerBase - jitter, innerBase + jitter),
          reason: 'seed $seed inner arm (base $innerBase)',
        );
        expect(
          hammers[1].angularSpeed,
          inInclusiveRange(-(outerBase + jitter), -(outerBase - jitter)),
          reason: 'seed $seed outer arm (base -$outerBase)',
        );
      }
    });

    test('spawn_slots_are_distinct_and_idle_safe_inside_head_bands', () {
      final map = HammerArenaMap.hammerArena(3);

      expect(map.spawnPoints, hasLength(4));
      final seen = <double>[];
      // The lowest mallet head band starts at 6.9 - headLength; a
      // spawn (plus a standing player's axis-aligned extent, ~0.85 m
      // diagonal half-extent) must stay inside it so an idle spawn
      // survives every arm pass (idle-safe >= 5 s, game doc § Level
      // design).
      final safeRadius = 6.9 - (map.hammers[1].headLength ?? 0) - 0.85;
      for (final spawn in map.spawnPoints) {
        seen.add(spawn.x);
        expect(
          spawn.length,
          lessThan(safeRadius),
          reason: 'spawn $spawn must sit inside the mallet bands',
        );
        expect(spawn.y, greaterThan(0), reason: 'spawns sit on the slab');
      }
      expect(seen.toSet().length, seen.length);
    });

    test('center_slab_seals_the_platform_interior', () {
      final map = HammerArenaMap.hammerArena(3);

      final tiers = map.shrink.tierRadii(map.platformRadius);
      final step = tiers[0] - tiers[1];
      // Slab top sits one tier-step below the settled platform so
      // its ledge stays standable after full shrink, and the slab
      // reaches past the innermost tier's inner polygon edge so no
      // annular gap remains inside.
      expect(
        map.centerSlab.center.y + map.centerSlab.height / 2,
        closeTo(tiers.last - step, 1e-9),
      );
      final innerEdge =
          (tiers.last - map.platformThickness / 2) * math.cos(math.pi / 16);
      expect(map.centerSlab.width / 2, greaterThan(innerEdge));
    });

    test('mallet_head_bands_sweep_the_standable_steps', () {
      final map = HammerArenaMap.hammerArena(3);

      for (final hammer in map.hammers) {
        final headLength = hammer.headLength!;
        // The platform spans radii 4.5 (settled) to 7 (pre-shrink
        // rim); each head band [radius - headLength, radius] must
        // overlap that standable span.
        expect(
          hammer.radius,
          greaterThan(map.shrink.endRadius),
          reason: 'head tip must reach past the settled platform',
        );
        expect(
          hammer.radius - headLength,
          lessThan(map.platformRadius),
          reason: 'head band must overlap the standable steps',
        );
      }
    });
  });

  test('mallet_phases_stay_within_seed_jitter_window', () {
    const halfWindow = math.pi / 6;
    for (final seed in [0, 7, 42]) {
      final hammers = HammerArenaMap.hammerArena(seed).hammers;
      // Arm phases jitter around 0 and pi respectively.
      expect(
        _angularDistance(hammers[0].initialAngle, 0),
        lessThanOrEqualTo(halfWindow + 1e-9),
        reason: 'seed $seed arm 0 phase',
      );
      expect(
        _angularDistance(hammers[1].initialAngle, math.pi),
        lessThanOrEqualTo(halfWindow + 1e-9),
        reason: 'seed $seed arm 1 phase',
      );
    }
  });
}

double _angularDistance(double a, double b) {
  const tau = 2 * math.pi;
  final d = (((a - b) % tau) + tau) % tau;
  return math.min(d, tau - d);
}
