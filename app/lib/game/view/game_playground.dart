import 'dart:async';

import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/auto_input_source.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Embeds a [RaceGameView] in a [GameWidget] with the one-button
/// controls on top (GDD § 3: auto-run right, the button jumps),
/// and forwards raw finish events to the UI.
///
/// Wiring only (architecture doc § 6): no rules — [onFinishEvent]
/// hands the untouched domain event to whoever judges it.
final class GamePlayground extends StatefulWidget {
  /// Creates the playground over [simulation].
  const GamePlayground({
    required this.simulation,
    required this.localPlayerId,
    required this.map,
    this.inputSource,
    this.onFinishEvent,
    super.key,
  });

  /// Key of the one-button action control (tests).
  static const Key actionButtonKey = Key('playground_action_button');

  /// Simulation stepped and rendered.
  final RaceSimulation simulation;

  /// Locally controlled player.
  final PlayerId localPlayerId;

  /// Course data for the renderer.
  final CourseMap map;

  /// Optional injected input (tests); defaults to the one-button
  /// auto-run source.
  final InputSource? inputSource;

  /// Invoked with every raw [PlayerFinished] event.
  final void Function(PlayerFinished event)? onFinishEvent;

  @override
  State<GamePlayground> createState() => _GamePlaygroundState();
}

final class _GamePlaygroundState extends State<GamePlayground> {
  late final ActionInputController _controller = ActionInputController();
  late final RaceGameView _game;
  StreamSubscription<PlayerFinished>? _finishSubscription;

  @override
  void initState() {
    super.initState();
    _game = RaceGameView(
      simulation: widget.simulation,
      localPlayerId: widget.localPlayerId,
      map: widget.map,
      inputSource:
          widget.inputSource ??
          AutoInputSource(
            gameId: trapRaceId,
            controller: _controller,
            simulation: widget.simulation,
            humanId: widget.localPlayerId,
            roster: [widget.localPlayerId],
          ),
    );
    _finishSubscription = _game.events
        .where((event) => event is PlayerFinished)
        .cast<PlayerFinished>()
        .listen(widget.onFinishEvent?.call);
  }

  @override
  void dispose() {
    _finishSubscription?.cancel();
    _game.onRemove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useOneButton = widget.inputSource == null;
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: _game)),
        if (useOneButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: _ActionIconButton(
                buttonKey: GamePlayground.actionButtonKey,
                label: 'JUMP',
                onPress: _controller.press,
                onRelease: _controller.release,
              ),
            ),
          ),
      ],
    );
  }
}

/// Minimal round action button (internal stand-in; the design
/// system's TtrActionButton replaces it later): fires [onPress] on
/// tap-down so the edge reaches the simulation on the press
/// itself, [onRelease] on tap-up/cancel.
final class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.buttonKey,
    required this.label,
    required this.onPress,
    required this.onRelease,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  /// UI geometry constant: button diameter, logical pixels.
  /// Display-only — big enough to thumb reliably mid-game.
  static const double diameterPx = 88;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onPress(),
      onTapUp: (_) => onRelease(),
      onTapCancel: onRelease,
      child: Container(
        width: diameterPx,
        height: diameterPx,
        decoration: const BoxDecoration(
          color: Color(0x663E5C76),
          shape: BoxShape.circle,
        ),
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
