import 'package:app/design/arena_palette.dart';
import 'package:app/design/game_hud/ttr_action_button.dart';
import 'package:app/design/tokens.dart';
import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/auto_input_source.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flame/game.dart' show Game, GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_PLAY widget for a solo match: mounts the session's
/// simulation with the human on the one-button controls (GDD § 3:
/// automatic movement + a single JUMP button) and the session's
/// bot brains feeding the game view's tick-inputs provider.
///
/// Race rounds render through [RaceGameView]; an unexpected
/// sim/map pairing falls back to a headless status pane (same
/// accumulator policy, driven by a frame `Ticker`). Wiring only —
/// judging stays in the driver's domain resolve (architecture doc
/// § 2), timers only here in the widget layer.
final class SoloPlayView extends StatefulWidget {
  /// Creates the view over [session].
  const SoloPlayView({
    required this.session,
    this.humanColorIndex = 0,
    super.key,
  });

  /// Key of the one-button action control (tests).
  static const Key actionButtonKey = Key('solo_action_button');

  /// The round to mount (from [SoloMatchController.currentRound]).
  final SoloRoundSession session;

  /// Palette index of the human's persisted profile color; the
  /// local body renders with it (GDD § 8.1).
  final int humanColorIndex;

  @override
  State<SoloPlayView> createState() => _SoloPlayViewState();
}

final class _SoloPlayViewState extends State<SoloPlayView> {
  late final ActionInputController _controller = ActionInputController();

  Game? _game;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    session.driver.humanInput = AutoInputSource(
      gameId: session.minigameId,
      controller: _controller,
      simulation: session.simulation,
      humanId: session.humanId,
      roster: session.rosterIds,
    );
    _game = _buildGame(session);
  }

  Game? _buildGame(SoloRoundSession session) {
    final simulation = session.simulation;
    final map = session.map;
    final palette = ArenaPalette(
      playerLocal: PlayerPalette.forIndex(widget.humanColorIndex),
    );
    if (simulation is RaceSimulation && map is CourseMap) {
      return RaceGameView(
        simulation: simulation,
        localPlayerId: session.humanId,
        map: map,
        playerIds: session.rosterIds,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
        palette: palette,
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
          Positioned(
            left: 0,
            right: 0,
            // Respect the bottom system-inset (gesture area when the
            // bars are swiped back in) on top of the visual margin.
            bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
            child: Center(
              child: TtrActionButton(
                key: SoloPlayView.actionButtonKey,
                label: switch (ActionInputController.verbFor(
                  widget.session.minigameId,
                )) {
                  GameVerb.jump => 'JUMP',
                  GameVerb.dash => 'DASH',
                },
                onPressed: _controller.press,
                onReleased: _controller.release,
              ),
            ),
          ),
        ],
      );
    }
    return _HeadlessRoundPane(session: widget.session);
  }
}

/// Fallback for rounds whose sim/map types have no renderer yet: a
/// frame ticker drives the session's fixed-dt ticks headlessly (same
/// accumulator policy as the game view) and shows a status pane.
final class _HeadlessRoundPane extends StatefulWidget {
  const _HeadlessRoundPane({required this.session});

  final SoloRoundSession session;

  @override
  State<_HeadlessRoundPane> createState() => _HeadlessRoundPaneState();
}

final class _HeadlessRoundPaneState extends State<_HeadlessRoundPane>
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
      color: const ArenaPalette().background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.minigameId,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Bots are playing — rendering unavailable.'),
            const SizedBox(height: 8),
            Text('tick ${session.driver.tickCount}'),
          ],
        ),
      ),
    );
  }
}
