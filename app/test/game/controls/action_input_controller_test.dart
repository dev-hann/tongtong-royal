import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

const raceId = 'trap_race';
const hammerId = 'hammer_dodge';
const hillId = 'king_of_the_hill';

void main() {
  HillArenaMap hillMap() => HillArenaMap.kingOfTheHill(1);

  ActionInputController hillController() => ActionInputController(
        policies: {hillId: HillSteering.fromArenaMap(hillMap())},
      );

  group('ActionInputController verb wiring', () {
    test('race: press fires a jump edge exactly once per press', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      controller.press();
      expect(controller.sampleFor(raceId, obs).jumpPressed, isTrue);
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);

      controller
        ..release()
        ..press();
      expect(controller.sampleFor(raceId, obs).jumpPressed, isTrue,
          reason: 'a fresh press after release fires a fresh edge');
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
    });

    test('hammer: button maps to jump', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(
        tick: 0,
        selfX: HammerSteering.centerBandMeters + 2,
        selfY: 0,
      );

      controller.press();
      final state = controller.sampleFor(hammerId, obs);
      expect(state.jumpPressed, isTrue);
      expect(state.dashPressed, isFalse);
      expect(state.moveDir.x, -1,
          reason: 'hammer auto-steering seeks the center');
    });

    test('hill: button maps to dash', () {
      final controller = hillController();
      final obs = SteeringObservation(
        tick: 0,
        selfX: hillMap().crownCenter.x - 0.8,
        selfY: hillMap().crownTopY + 0.8,
      );

      controller.press();
      final state = controller.sampleFor(hillId, obs);
      expect(state.dashPressed, isTrue);
      expect(state.jumpPressed, isFalse);
      expect(state.moveDir.x, greaterThan(0),
          reason: 'dash impulse follows the dash target direction');
    });

    test('press while already pressed does not queue a second edge', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      controller
        ..press()
        ..press();
      expect(controller.sampleFor(raceId, obs).jumpPressed, isTrue);
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
    });

    test('release without press is inert', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      controller.release();
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
    });

    test('unknown game id throws ArgumentError', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);
      expect(
        () => controller.sampleFor('unknown-game', obs),
        throwsArgumentError,
      );
    });

    test('hill without a registered policy throws ArgumentError', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);
      expect(() => controller.sampleFor(hillId, obs), throwsArgumentError);
    });
  });

  group('ActionInputController composition', () {
    test('combines auto-steer move with the button edge (race)', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 5, selfY: 2);

      controller.press();
      final state = controller.sampleFor(raceId, obs);
      expect(state.moveDir.x, 1);
      expect(state.jumpPressed, isTrue);
    });

    test('hill auto-jump passes through without a button press', () {
      final map = hillMap();
      final controller = hillController();
      final rampMinX = map.ramps[3].center.x - map.ramps[3].width / 2;

      final state = controller.sampleFor(
        hillId,
        SteeringObservation(
          tick: 0,
          selfX: rampMinX - 0.5,
          selfY: 0.8,
        ),
      );
      expect(state.jumpPressed, isTrue,
          reason: 'ramp auto-jump is automatic, not button-driven');
      expect(state.dashPressed, isFalse);
    });

    test('NaN observation yields a sanitized zero move vector', () {
      final controller = ActionInputController();
      const nan = double.nan;
      final state = controller.sampleFor(
        hammerId,
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );
      expect(state.moveDir, Vector2.zero());
    });

    test('outputs stay within the unit box', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(
        tick: 0,
        selfX: -1000000000,
        selfY: 1000000000,
        selfVx: -1,
      );
      final state = controller.sampleFor(hammerId, obs);
      expect(state.moveDir.x.abs(), lessThanOrEqualTo(1));
      expect(state.moveDir.y.abs(), lessThanOrEqualTo(1));
    });
  });

  group('GameVerb lookup', () {
    test('race and hammer use jump; hill uses dash', () {
      expect(ActionInputController.verbFor(raceId), GameVerb.jump);
      expect(ActionInputController.verbFor(hammerId), GameVerb.jump);
      expect(ActionInputController.verbFor(hillId), GameVerb.dash);
    });

    test('unknown id throws', () {
      expect(() => ActionInputController.verbFor('nope'), throwsArgumentError);
    });
  });
}
