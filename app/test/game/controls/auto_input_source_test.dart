import 'dart:async';

import 'package:app/game/arenas/hill/hill_arena_map.dart';
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

PlayerPose pose(double x, double y) =>
    (x: x, y: y, angle: 0, vx: 0, vy: 0);

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
    final map = HillArenaMap.kingOfTheHill(1);
    final y = map.crownTopY + 0.8;
    final sim = _FakeSim({
      humanId: pose(map.crownCenter.x + 0.6, y),
      'bot-1': pose(map.crownCenter.x + 1.7, y),
      'bot-2': pose(500, y),
    });
    final controller = ActionInputController(
      policies: {kingOfTheHillId: HillSteering.fromArenaMap(map)},
    );
    final source = AutoInputSource(
      gameId: kingOfTheHillId,
      controller: controller,
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    controller.press();
    final state = source.sample();
    expect(state.dashPressed, isTrue);
    expect(state.moveDir.x, greaterThan(0),
        reason: 'bot-1 (near, on crown) is the dash target; '
            'bot-2 at x=500 is filtered out');
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

  test('tick counter advances per sample (cooldown bookkeeping)', () {
    final map = HillArenaMap.kingOfTheHill(1);
    final rampMinX = map.ramps[3].center.x - map.ramps[3].width / 2;
    final sim = _FakeSim({humanId: pose(rampMinX - 0.5, 0.8)});
    final controller = ActionInputController(
      policies: {kingOfTheHillId: HillSteering.fromArenaMap(map)},
    );
    final source = AutoInputSource(
      gameId: kingOfTheHillId,
      controller: controller,
      simulation: sim,
      humanId: humanId,
      roster: roster,
    );

    expect(source.sample().jumpPressed, isTrue);
    expect(source.sample().jumpPressed, isFalse,
        reason: 'internal tick advanced, cooldown engaged');
  });
}

const kingOfTheHillId = 'king_of_the_hill';
