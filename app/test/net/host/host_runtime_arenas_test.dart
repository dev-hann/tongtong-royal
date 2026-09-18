import 'dart:async';

import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/arenas/hill/hill_simulation.dart';
import 'package:app/game/round_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import 'host_harness.dart';

/// Minimal seam double: completes on demand, no bodies, no events.
final class _FakeRoundSimulation implements RoundSimulation {
  final StreamController<RoundEvent> _sink =
      StreamController<RoundEvent>.broadcast(sync: true);

  bool complete = false;

  @override
  Stream<RoundEvent> get events => _sink.stream;

  @override
  bool get isComplete => complete;

  @override
  double? get progressAnchorX => null;

  @override
  PlayerPose? poseOf(PlayerId playerId) => null;

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {}

  @override
  void dispose() => _sink.close();
}

void main() {
  group('HostRuntime arena rounds (per-minigame dispatch)', () {
    test(
      "timeout ticks derive from each started round's minigame spec",
      () async {
        final fake = _FakeRoundSimulation();
        final h = HostHarness(
          simulationFactory: (minigameId, mapSeed, players) => fake,
        );
        addTearDown(h.client.dispose);
        await h.boot();

        const cases = [
          ('trap_race', 90 * PhysicsConsts.tickRate),
          ('hammer_dodge', 60 * PhysicsConsts.tickRate),
          ('king_of_the_hill', 75 * PhysicsConsts.tickRate),
        ];
        for (final (id, expectedTicks) in cases) {
          fake.complete = false;
          h.runtime.startRound(0, id, 7);
          expect(h.runtime.roundTimeoutTicks, expectedTicks, reason: id);
          expect(h.sentMessages.whereType<RoundStarting>().last.minigameId, id);
          // Simulation-declared completion ends the round on the next
          // tick regardless of the timeout budget.
          fake.complete = true;
          h.tick();
          expect(h.runtime.isRoundActive, isFalse, reason: id);
          expect(
            h.sentMessages
                .whereType<RoundResultsMessage>()
                .last
                .roundResult
                .minigameId,
            id,
            reason: id,
          );
        }
      },
    );

    test('unknown minigame id is rejected by the registry lookup', () async {
      final h = HostHarness(
        simulationFactory: (minigameId, mapSeed, players) =>
            _FakeRoundSimulation(),
      );
      addTearDown(h.client.dispose);
      await h.boot();

      expect(
        () => h.runtime.startRound(0, 'no_such_game', 7),
        throwsArgumentError,
      );
    });
  });

  group('HostRuntime hammer_dodge round', () {
    test(
      'elimination ends the round; survivor places first (GDD 7.5)',
      () async {
        final h = HostHarness(
          roster: const {p1, p2},
          simulationFactory: (minigameId, mapSeed, players) => HammerSimulation(
            map: hammerlessArena(mapSeed),
            playerIds: players,
          ),
        );
        addTearDown(h.client.dispose);
        await h.boot();
        final completed = <RoundResult>[];
        h.runtime.onRoundComplete.listen(completed.add);

        h.runtime.startRound(2, 'hammer_dodge', 7);
        final starting = h.sentMessages.whereType<RoundStarting>().single;
        expect(starting.minigameId, 'hammer_dodge');
        expect(starting.timeoutMs, const HammerDodge().spec.timeoutMs);
        expect(starting.roundIndex, 2);

        // Snapshot cadence holds before any elimination: every 3rd
        // host tick (network doc § 1), both bodies present.
        h.driveRight(playerId: p1, ticks: 600);
        expect(h.runtime.isRoundActive, isFalse, reason: 'p1 must be out');
        final early = h.snapshotsSent.take(5).map((s) => s.tick).toList();
        expect(early, const [3, 6, 9, 12, 15]);

        final message = h.sentMessages.whereType<RoundResultsMessage>().single;
        final result = message.roundResult;
        expect(result.roundIndex, 2);
        expect(result.minigameId, 'hammer_dodge');
        expect(result.placements.first.playerId, p2);
        expect(result.placements.first.rank, 1);
        expect(result.placements.last.playerId, p1);
        expect(result.placements.last.rank, 2);
        expect(completed.single.placements, result.placements);

        // Every snapshot carries the survivor; snapshots after p1's
        // last appearance never contain the destroyed body.
        expect(
          h.snapshotsSent.every((s) => s.players.any((p) => p.playerId == p2)),
          isTrue,
        );
        final lastP1Tick = h.snapshotsSent
            .lastWhere((s) => s.players.any((p) => p.playerId == p1))
            .tick;
        final afterP1 = h.snapshotsSent
            .where((s) => s.tick > lastP1Tick)
            .toList();
        for (final s in afterP1) {
          expect(s.players.map((p) => p.playerId), [p2]);
        }
      },
    );
  });

  group('HostRuntime king_of_the_hill round', () {
    test('timeout path ranks by hold time (GDD 4.3)', () async {
      late HillSimulation sim;
      final h = HostHarness(
        roster: const {p1, p2},
        simulationFactory: (minigameId, mapSeed, players) =>
            sim = HillSimulation.forTesting(
              map: HillArenaMap.kingOfTheHill(mapSeed),
              playerIds: players,
              stuckThresholdSeconds: 5,
              timeoutTicks: 600,
            ),
      );
      addTearDown(h.client.dispose);
      await h.boot();
      final completed = <RoundResult>[];
      h.runtime.onRoundComplete.listen(completed.add);

      h.runtime.startRound(1, 'king_of_the_hill', 7);
      final starting = h.sentMessages.whereType<RoundStarting>().single;
      expect(starting.minigameId, 'king_of_the_hill');
      expect(starting.timeoutMs, const KingOfTheHill().spec.timeoutMs);

      // Park p1 on the crown (fixture parity with the HillSimulation
      // suite); park p2 on the open floor away from the ramps.
      sim.bodyOf(p1).setTransform(_onCrownTop(sim.map), 0);
      sim.bodyOf(p2).setTransform(Vector2(-5, 0.45), 0);

      // Attribution: only p2's input drives a body.
      h.runtime.submitMemberInput(p2, inputSample(seq: 1, moveX: -1));
      for (var i = 0; i < 30 && h.runtime.isRoundActive; i++) {
        h.tick();
      }
      final early = h.snapshotsSent.take(5).map((s) => s.tick).toList();
      expect(early, const [3, 6, 9, 12, 15]);
      final moved = h.snapshotsSent.last.players.firstWhere(
        (p) => p.playerId == p2,
      );
      expect(moved.x, lessThan(-6), reason: 'p2 input must drive p2 only');

      // Park p2 again and idle out the rest of the round.
      h.runtime.submitMemberInput(p2, inputSample(seq: 2));
      sim.bodyOf(p2).setTransform(Vector2(-5, 0.45), 0);

      // Sim-declared timeout completes the round through isComplete.
      while (h.runtime.isRoundActive) {
        h.tick();
      }
      expect(sim.isComplete, isTrue);

      final result = h.sentMessages
          .whereType<RoundResultsMessage>()
          .single
          .roundResult;
      expect(result.roundIndex, 1);
      expect(result.minigameId, 'king_of_the_hill');
      expect(result.placements.first.playerId, p1);
      expect(result.placements.first.rank, 1);
      expect(result.placements.last.playerId, p2);
      expect(result.placements.last.rank, 2);
      expect(completed.single.placements, result.placements);
      expect(h.snapshotsSent, hasLength(200), reason: '600 ticks / 3');
    });
  });
}

Vector2 _onCrownTop(HillArenaMap map) =>
    Vector2(map.crownCenter.x, map.crownTopY + 0.76 + 0.01);
