import 'package:app/game/player_input.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

/// UI geometry constant: joystick drag distance (logical px) at which
/// the movement vector saturates at magnitude 1. Display-only; the
/// sampled vector is sanitized regardless ([PlayerInputState]).
const double joystickRadiusPx = 64;

/// UI geometry constant: drags shorter than this (logical px) read as
/// a neutral stick, filtering finger jitter. Display-only.
const double joystickDeadZonePx = 8;

/// Touch [InputSource]: samples what the on-screen controls last
/// reported.
///
/// The widget half ([TouchInputSource]) writes raw gestures here; the
/// game loop reads sanitized [PlayerInputState]s via [sample]. Edge
/// flags are queued on press and consumed by the next sample, so a
/// jump/dash is true for exactly one tick.
final class TouchInputController implements InputSource {
  final Vector2 _moveDir = Vector2.zero();
  bool _jumpQueued = false;
  bool _dashQueued = false;

  /// Joystick vector in screen pixels; positive y is screen-down
  /// (flipped to world-up internally).
  void updateJoystick(Vector2 deltaPx) {
    if (deltaPx.length < joystickDeadZonePx) {
      _moveDir.setZero();
      return;
    }
    final scaled = deltaPx.scaled(1 / joystickRadiusPx);
    if (scaled.length > 1) {
      scaled.normalize();
    }
    // Screen y grows downward; the world's y grows upward.
    _moveDir.setValues(scaled.x, -scaled.y);
  }

  /// Resets the stick to neutral (finger lifted).
  void releaseJoystick() {
    _moveDir.setZero();
  }

  /// Queues a jump edge for the next [sample].
  void pressJump() {
    _jumpQueued = true;
  }

  /// Queues a dash edge for the next [sample].
  void pressDash() {
    _dashQueued = true;
  }

  @override
  PlayerInputState sample() {
    final state = PlayerInputState(
      moveDir: _moveDir.clone(),
      jumpPressed: _jumpQueued,
      dashPressed: _dashQueued,
    );
    _jumpQueued = false;
    _dashQueued = false;
    return state;
  }
}

/// Full-bleed overlay with the M1 touch controls: virtual joystick on
/// the left half, jump and dash buttons on the bottom right. Writes
/// gestures into [controller]; holds no game knowledge (architecture
/// doc § 6).
final class TouchInputSource extends StatefulWidget {
  /// Creates the overlay feeding [controller].
  const TouchInputSource({required this.controller, super.key});

  /// Key of the left-half joystick drag surface (tests).
  static const Key joystickAreaKey = Key('touch_joystick_area');

  /// Key of the jump button (tests).
  static const Key jumpButtonKey = Key('touch_jump_button');

  /// Key of the dash button (tests).
  static const Key dashButtonKey = Key('touch_dash_button');

  /// Input state written by this overlay's gestures.
  final TouchInputController controller;

  @override
  State<TouchInputSource> createState() => _TouchInputSourceState();
}

final class _TouchInputSourceState extends State<TouchInputSource> {
  Offset _joystickDrag = Offset.zero;

  void _onPanStart(DragStartDetails details) {
    _joystickDrag = Offset.zero;
    widget.controller.releaseJoystick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _joystickDrag += details.delta;
    widget.controller.updateJoystick(
      Vector2(_joystickDrag.dx, _joystickDrag.dy),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    _joystickDrag = Offset.zero;
    widget.controller.releaseJoystick();
  }

  void _onPanCancel() {
    _joystickDrag = Offset.zero;
    widget.controller.releaseJoystick();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: GestureDetector(
                key: TouchInputSource.joystickAreaKey,
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onPanCancel: _onPanCancel,
              ),
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                buttonKey: TouchInputSource.dashButtonKey,
                label: 'DASH',
                diameter: 64,
                color: const Color(0x66B23A48),
                onPress: widget.controller.pressDash,
              ),
              const SizedBox(width: 16),
              _ControlButton(
                buttonKey: TouchInputSource.jumpButtonKey,
                label: 'JUMP',
                diameter: 80,
                color: const Color(0x663E5C76),
                onPress: widget.controller.pressJump,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Round touch button: fires [onPress] on tap-down so edges reach the
/// simulation on the press itself.
final class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.buttonKey,
    required this.label,
    required this.diameter,
    required this.color,
    required this.onPress,
  });

  final Key buttonKey;
  final String label;
  final double diameter;
  final Color color;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPress(),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
