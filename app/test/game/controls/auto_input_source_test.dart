import 'dart:async';

import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/auto_input_source.dart';
import 'package:app/game/controls/steering.dart';
import 'package:app/game/round_simulation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

final class _FakeSim implements RoundSimulation {
  _FakeSim(this.poses);

  final Map<PlayerId, PlayerPose> poses;

  @override
  Stream<RoundEvent> get events => const Stream.empty();

  @override
  bool get isComplete => false;

  @override
  double? get progressAnchorX => null;

  @override
  PlayerPose? poseOf(PlayerId playerId) => poses[playerId];

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {}

  @override
  void dispose() {}
}

/// Test policy: walks toward the nearest observed player (sign of
/// the smallest |dx|).
final class _TowardNearestPlayer implements SteeringPolicy {
  const _TowardNearestPlayer();

  @override
  SteeringDecision sample(SteeringObservation obs) {
    if (obs.nearbyPlayers.isEmpty) {
      return SteeringDecision(moveDir: Vector2.zero());
    }
    var nearest = obs.nearbyPlayers.first;
    for (final other in obs.nearbyPlayers) {
      if ((other.x - obs.selfX).abs() < (nearest.x - obs.selfX).abs()) {
        nearest = other;
      }
    }
    final dx = nearest.x - obs.selfX;
    return SteeringDecision(moveDir: Vector2(dx.sign, 0));
  }
}

/// Test policy: auto-jumps on the first sample only (tick 0).
final class _JumpOnFirstTick implements SteeringPolicy {
  const _JumpOnFirstTick();

  @override
  SteeringDecision sample(SteeringObservation obs) {
    return SteeringDecision(moveDir: Vector2(1, 0), jumpPressed: obs.tick == 0);
  }
}

PlayerPose pose(double x, double y) => (x: x, y: y, angle: 0, vx: 0, vy: 0);

void main() {
  const humanId = 'human';
  const roster = ['human', 'bot-1', 'bot-2'];

  test('race: samples the constant auto-run move', () {
    final sim = _FakeSim({humanId: pose(0, 1)});
    final source = AutoInputSource(
      gameId: 'trap_race',
      controller: ActionInputController(),
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    final state = source.sample();
    expect(state.moveDir.x, 1);
    expect(state.jumpPressed, isFalse);
  });

  test('button edge composed with auto-steer reaches the sample', () {
    final sim = _FakeSim({humanId: pose(0, 1)});
    final controller = ActionInputController();
    final source = AutoInputSource(
      gameId: 'trap_race',
      controller: controller,
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    controller.press();
    expect(source.sample().jumpPressed, isTrue);
    expect(source.sample().jumpPressed, isFalse);
  });

  test('nearby players are filtered to the awareness radius', () {
    final sim = _FakeSim({
      humanId: pose(0, 1),
      'bot-1': pose(1.7, 1),
      'bot-2': pose(500, 1),
    });
    final controller = ActionInputController(
      policies: {raceId: const _TowardNearestPlayer()},
    );
    final source = AutoInputSource(
      gameId: raceId,
      controller: controller,
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    final state = source.sample();
    expect(
      state.moveDir.x,
      greaterThan(0),
      reason:
          'bot-1 (near) drives the steering; '
          'bot-2 at x=500 is filtered out',
    );
  });

  test('missing human pose yields sanitized idle input', () {
    final sim = _FakeSim({'bot-1': pose(0, 0)});
    final source = AutoInputSource(
      gameId: 'trap_race',
      controller: ActionInputController(),
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    final state = source.sample();
    expect(state.moveDir, Vector2.zero());
    expect(state.jumpPressed, isFalse);
    expect(state.dashPressed, isFalse);
  });

  test('tick counter advances per sample', () {
    final sim = _FakeSim({humanId: pose(0, 1)});
    final controller = ActionInputController(
      policies: {raceId: const _JumpOnFirstTick()},
    );
    final source = AutoInputSource(
      gameId: raceId,
      controller: controller,
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    expect(source.sample().jumpPressed, isTrue);
    expect(
      source.sample().jumpPressed,
      isFalse,
      reason: 'internal tick advanced past the policy window',
    );
  });
}

const raceId = 'trap_race';
