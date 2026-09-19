import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

const raceId = 'trap_race';
const hammerId = 'hammer_dodge';
const removedHillId = 'king_of_the_hill';

void main() {
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

    test('removed king_of_the_hill id has no policy and throws', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);
      expect(
        () => controller.sampleFor(removedHillId, obs),
        throwsArgumentError,
      );
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
    test('race and hammer use jump', () {
      expect(ActionInputController.verbFor(raceId), GameVerb.jump);
      expect(ActionInputController.verbFor(hammerId), GameVerb.jump);
    });

    test('unknown id throws', () {
      expect(() => ActionInputController.verbFor('nope'), throwsArgumentError);
    });

    test('removed king_of_the_hill id throws like any unknown id', () {
      expect(
        () => ActionInputController.verbFor(removedHillId),
        throwsArgumentError,
      );
    });

    test('dash verb stays in the vocabulary for future games', () {
      expect(GameVerb.values, containsAll([GameVerb.jump, GameVerb.dash]));
    });
  });
}
