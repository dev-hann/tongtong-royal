import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/arena/arena_game_view.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:app/game/view/touch_input_source.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flame/game.dart' show Game, GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_PLAY widget for a solo match: mounts the session's
/// simulation with the human on the touch overlay and the session's
/// bot brains feeding the game view's tick-inputs provider.
///
/// Race rounds render through [RaceGameView], arena rounds (Hammer
/// Dodge, King of the Hill) through [ArenaGameView]; unexpected
/// sim/map combinations fall back to a headless status pane (same
/// accumulator policy, driven by a frame `Ticker`). Wiring only —
/// judging stays in the driver's domain resolve (architecture
/// doc § 2), timers only here in the widget layer.
final class SoloPlayView extends StatefulWidget {
  /// Creates the view over [session].
  const SoloPlayView({required this.session, super.key});

  /// The round to mount (from [SoloMatchController.currentRound]).
  final SoloRoundSession session;

  @override
  State<SoloPlayView> createState() => _SoloPlayViewState();
}

final class _SoloPlayViewState extends State<SoloPlayView> {
  late final TouchInputController _touchController = TouchInputController();
  Game? _game;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    session.driver.humanInput = _touchController;
    _game = _buildGame(session);
  }

  Game? _buildGame(SoloRoundSession session) {
    final simulation = session.simulation;
    final map = session.map;
    if (simulation is RaceSimulation && map is CourseMap) {
      return RaceGameView(
        simulation: simulation,
        localPlayerId: session.humanId,
        map: map,
        playerIds: session.rosterIds,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
      )..onStep = session.driver.postTick;
    }
    if (map is HammerArenaMap) {
      return ArenaGameView.hammer(
        simulation: simulation,
        map: map,
        localPlayerId: session.humanId,
        playerIds: session.rosterIds,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
      )..onStep = session.driver.postTick;
    }
    if (map is HillArenaMap) {
      return ArenaGameView.hill(
        simulation: simulation,
        map: map,
        localPlayerId: session.humanId,
        playerIds: session.rosterIds,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
      )..onStep = session.driver.postTick;
    }
    // Unexpected archetype pairing: run headlessly instead of
    // crashing (defensive fallback, kept from the pre-renderer pane).
    return null;
  }

  @override
  void dispose() {
    if (_game case final RaceGameView race) {
      race.onRemove();
    }
    widget.session.driver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game != null) {
      return Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          Positioned.fill(
            child: TouchInputSource(controller: _touchController),
          ),
        ],
      );
    }
    return _ArenaRoundPane(session: widget.session);
  }
}

/// Fallback for rounds whose sim/map types have no renderer yet: a
/// frame ticker drives the session's fixed-dt ticks headlessly (same
/// accumulator policy as the game views) and shows a status pane.
final class _ArenaRoundPane extends StatefulWidget {
  const _ArenaRoundPane({required this.session});

  final SoloRoundSession session;

  @override
  State<_ArenaRoundPane> createState() => _ArenaRoundPaneState();
}

final class _ArenaRoundPaneState extends State<_ArenaRoundPane>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _accumulatorSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    if (!mounted || widget.session.isOver) {
      return;
    }
    final frameSeconds = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (!frameSeconds.isFinite || frameSeconds <= 0) {
      return;
    }
    _accumulatorSeconds += frameSeconds;
    var steps = 0;
    while (_accumulatorSeconds >= PhysicsConsts.fixedDt &&
        steps < maxStepsPerFrame &&
        !widget.session.isOver) {
      widget.session.driver.tick();
      _accumulatorSeconds -= PhysicsConsts.fixedDt;
      steps++;
    }
    if (steps == maxStepsPerFrame) {
      _accumulatorSeconds = 0;
    }
    if (steps > 0 && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ColoredBox(
      color: const Color(0xFF101820),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.minigameId,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Bots are playing — arena rendering is upcoming.'),
            const SizedBox(height: 8),
            Text('tick ${session.driver.tickCount}'),
          ],
        ),
      ),
    );
  }
}
