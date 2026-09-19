import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';

const raceId = 'trap_race';
const removedHammerId = 'hammer_dodge';
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
      expect(
        controller.sampleFor(raceId, obs).jumpPressed,
        isTrue,
        reason: 'a fresh press after release fires a fresh edge',
      );
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
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

    test('removed hammer_dodge id has no policy and throws', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);
      expect(
        () => controller.sampleFor(removedHammerId, obs),
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

    test('NaN observation yields a sanitized move vector', () {
      final controller = ActionInputController();
      const nan = double.nan;
      final state = controller.sampleFor(
        raceId,
        const SteeringObservation(tick: 0, selfX: nan, selfY: nan),
      );
      expect(
        state.moveDir.x,
        1,
        reason: 'race policy is pose-independent (constant right)',
      );
    });

    test('outputs stay within the unit box', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(
        tick: 0,
        selfX: -1000000000,
        selfY: 1000000000,
        selfVx: -1,
      );
      final state = controller.sampleFor(raceId, obs);
      expect(state.moveDir.x.abs(), lessThanOrEqualTo(1));
      expect(state.moveDir.y.abs(), lessThanOrEqualTo(1));
    });
  });

  group('GameVerb lookup', () {
    test('race uses jump', () {
      expect(ActionInputController.verbFor(raceId), GameVerb.jump);
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

    test('removed hammer_dodge id throws like any unknown id', () {
      expect(
        () => ActionInputController.verbFor(removedHammerId),
        throwsArgumentError,
      );
    });

    test('dash verb stays in the vocabulary for future games', () {
      expect(GameVerb.values, containsAll([GameVerb.jump, GameVerb.dash]));
    });
  });
}
