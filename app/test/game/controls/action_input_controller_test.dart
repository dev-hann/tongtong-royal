import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/steering.dart';
import 'package:flutter_test/flutter_test.dart';

const raceId = 'trap_race';
const hammerId = 'hammer_dodge';
const removedHillId = 'king_of_the_hill';

void main() {
  group('ActionInputController verb wiring', () {
    test('press_fires_jump_edge_exactly_once_per_press', () {
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

    test('press_while_already_pressed_queues_no_second_edge', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      controller
        ..press()
        ..press();
      expect(controller.sampleFor(raceId, obs).jumpPressed, isTrue);
      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
    });

    test('release_without_press_is_inert', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      controller.release();

      expect(controller.sampleFor(raceId, obs).jumpPressed, isFalse);
    });

    test('unknown_game_id_throws_argument_error', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      expect(
        () => controller.sampleFor('unknown-game', obs),
        throwsArgumentError,
      );
    });

    test('removed_king_of_the_hill_id_has_no_policy_and_throws', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 0, selfY: 0);

      expect(
        () => controller.sampleFor(removedHillId, obs),
        throwsArgumentError,
      );
    });
  });

  group('ActionInputController composition', () {
    test('combines_auto_steer_move_with_button_edge_race', () {
      final controller = ActionInputController();
      const obs = SteeringObservation(tick: 0, selfX: 5, selfY: 2);

      controller.press();
      final state = controller.sampleFor(raceId, obs);

      expect(state.moveDir.x, 1);
      expect(state.jumpPressed, isTrue);
    });

    test('nan_observation_yields_sanitized_move_vector', () {
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

    test('outputs_stay_within_the_unit_box', () {
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

    test('hammer_dodge_uses_center_drift_steering_and_jump_edge', () {
      final controller = ActionInputController();
      const obsFarRight = SteeringObservation(
        tick: 0,
        selfX: HammerSteering.centerBandMeters + 2,
        selfY: 1,
      );

      controller.press();
      final state = controller.sampleFor(hammerId, obsFarRight);

      expect(
        state.moveDir.x,
        -1,
        reason: 'hammer policy steers back toward the arena center',
      );
      expect(state.jumpPressed, isTrue);
    });

    test('hammer_dodge_inside_center_band_idles_move', () {
      final controller = ActionInputController();
      const obsCentered = SteeringObservation(
        tick: 0,
        selfX: 0,
        selfY: 1,
      );

      final state = controller.sampleFor(hammerId, obsCentered);

      expect(state.moveDir.x, 0);
      expect(state.jumpPressed, isFalse);
    });
  });

  group('GameVerb lookup', () {
    test('race_uses_jump', () {
      expect(ActionInputController.verbFor(raceId), GameVerb.jump);
    });

    test('hammer_dodge_uses_jump', () {
      expect(ActionInputController.verbFor(hammerId), GameVerb.jump);
    });

    test('unknown_id_throws', () {
      expect(() => ActionInputController.verbFor('nope'), throwsArgumentError);
    });

    test('removed_king_of_the_hill_id_throws_like_any_unknown_id', () {
      expect(
        () => ActionInputController.verbFor(removedHillId),
        throwsArgumentError,
      );
    });

    test('dash_verb_stays_in_the_vocabulary_for_future_games', () {
      expect(GameVerb.values, containsAll([GameVerb.jump, GameVerb.dash]));
    });
  });
}
