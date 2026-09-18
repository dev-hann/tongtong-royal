import 'dart:async';

import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:app/game/view/touch_input_source.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Embeds a [RaceGameView] in a [GameWidget] with the touch controls
/// on top, and forwards raw finish events to the UI.
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

  /// Simulation stepped and rendered.
  final RaceSimulation simulation;

  /// Locally controlled player.
  final PlayerId localPlayerId;

  /// Course data for the renderer.
  final CourseMap map;

  /// Optional injected input (tests); defaults to the touch overlay.
  final InputSource? inputSource;

  /// Invoked with every raw [PlayerFinished] event.
  final void Function(PlayerFinished event)? onFinishEvent;

  @override
  State<GamePlayground> createState() => _GamePlaygroundState();
}

final class _GamePlaygroundState extends State<GamePlayground> {
  late final TouchInputController _touchController = TouchInputController();
  late final RaceGameView _game;
  StreamSubscription<PlayerFinished>? _finishSubscription;

  @override
  void initState() {
    super.initState();
    _game = RaceGameView(
      simulation: widget.simulation,
      localPlayerId: widget.localPlayerId,
      map: widget.map,
      inputSource: widget.inputSource ?? _touchController,
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
    final useTouchOverlay = widget.inputSource == null;
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: _game)),
        if (useTouchOverlay)
          Positioned.fill(
            child: TouchInputSource(controller: _touchController),
          ),
      ],
    );
  }
}
