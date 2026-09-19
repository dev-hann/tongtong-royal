import 'dart:async';

import 'package:app/game/round_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
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
  group('HostRuntime round dispatch', () {
    test(
      "timeout ticks derive from each started round's minigame spec",
      () async {
        final fake = _FakeRoundSimulation();
        final h = HostHarness(
          simulationFactory: (minigameId, mapSeed, players) => fake,
        );
        addTearDown(h.client.dispose);
        await h.boot();

        const cases = [('trap_race', 90 * PhysicsConsts.tickRate)];
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
      expect(
        () => h.runtime.startRound(0, 'hammer_dodge', 7),
        throwsArgumentError,
        reason: 'hammer_dodge left the registry with the scope reset',
      );
    });
  });
}
