import 'package:app/game/view/touch_input_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';

void main() {
  group('TouchInputController', () {
    test('drag right produces a positive x within unit length', () {
      final controller = TouchInputController()..updateJoystick(Vector2(32, 0));
      final state = controller.sample();
      expect(state.moveDir.x, greaterThan(0));
      expect(state.moveDir.x, closeTo(32 / joystickRadiusPx, 0.01));
      expect(state.moveDir.x, lessThanOrEqualTo(1));
    });

    test('screen-down drag maps to negative world y', () {
      final controller = TouchInputController()..updateJoystick(Vector2(0, 32));
      expect(controller.sample().moveDir.y, lessThan(0));
    });

    test('joystick magnitude saturates at 1', () {
      final controller = TouchInputController()
        ..updateJoystick(Vector2(500, 0));
      expect(controller.sample().moveDir.x, closeTo(1, 0.001));
    });

    test('tiny drags stay in the dead zone (neutral)', () {
      final controller = TouchInputController()..updateJoystick(Vector2(4, 0));
      expect(controller.sample().moveDir, Vector2.zero());
    });

    test('releaseJoystick returns to neutral', () {
      final controller = TouchInputController()
        ..updateJoystick(Vector2(32, 0))
        ..releaseJoystick();
      expect(controller.sample().moveDir, Vector2.zero());
    });

    test('jump edge is true for exactly one sample', () {
      final controller = TouchInputController()..pressJump();
      expect(controller.sample().jumpPressed, isTrue);
      expect(controller.sample().jumpPressed, isFalse);
    });

    test('dash edge is true for exactly one sample', () {
      final controller = TouchInputController()..pressDash();
      expect(controller.sample().dashPressed, isTrue);
      expect(controller.sample().dashPressed, isFalse);
    });
  });

  group('TouchInputSource widget', () {
    testWidgets('joystick drag feeds the controller', (tester) async {
      final controller = TouchInputController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TouchInputSource(controller: controller)),
        ),
      );

      final area = tester.getRect(find.byKey(TouchInputSource.joystickAreaKey));
      final gesture = await tester.startGesture(area.center);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      final state = controller.sample();
      expect(state.moveDir.x, greaterThan(0));
      expect(state.moveDir.x, lessThanOrEqualTo(1));

      await gesture.up();
      await tester.pump();
      expect(controller.sample().moveDir, Vector2.zero());
    });

    testWidgets('tapping jump queues one jump edge', (tester) async {
      final controller = TouchInputController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TouchInputSource(controller: controller)),
        ),
      );

      await tester.tap(find.byKey(TouchInputSource.jumpButtonKey));
      await tester.pump();

      expect(controller.sample().jumpPressed, isTrue);
      expect(controller.sample().jumpPressed, isFalse);
    });

    testWidgets('tapping dash queues one dash edge', (tester) async {
      final controller = TouchInputController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TouchInputSource(controller: controller)),
        ),
      );

      await tester.tap(find.byKey(TouchInputSource.dashButtonKey));
      await tester.pump();

      expect(controller.sample().dashPressed, isTrue);
      expect(controller.sample().dashPressed, isFalse);
    });
  });
}
