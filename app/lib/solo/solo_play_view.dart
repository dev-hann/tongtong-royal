import 'dart:async' show unawaited;

import 'package:app/design/game_hud/ttr_action_button.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_quit_dialog.dart';
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
    this.onQuit,
    super.key,
  });

  /// Key of the one-button action control (tests).
  static const Key actionButtonKey = Key('solo_action_button');

  /// Key of the top-right race-quit button (tests).
  static const Key quitButtonKey = Key('solo_quit_button');

  /// The round to mount (from [SoloMatchController.currentRound]).
  final SoloRoundSession session;

  /// Fired when the player confirms the mid-round quit dialog
  /// (GDD § 7.11): the shell abandons the match back to home.
  final VoidCallback? onQuit;

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

  /// Quit confirm (GDD § 7.11): QUIT fires [SoloPlayView.onQuit];
  /// every other dismissal keeps the race running.
  Future<void> _confirmQuit() async {
    final quit = await TtrQuitDialog.show(context);
    if (quit && mounted) {
      widget.onQuit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // System back is intercepted behind the same quit confirm as
    // the exit button (GDD § 7.11) — back never silently kills the
    // app mid-race.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_confirmQuit());
        }
      },
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (_game case final game?)
              Positioned.fill(child: GameWidget(game: game))
            else
              Positioned.fill(
                child: _HeadlessRoundPane(session: widget.session),
              ),
            Positioned(
              top: SpacingScale.sm,
              right: SpacingScale.sm,
              child: _QuitButton(
                key: SoloPlayView.quitButtonKey,
                onPressed: _confirmQuit,
              ),
            ),
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
        ),
      ),
    );
  }
}

/// Top-right race exit affordance (GDD § 7.11): surface chip so the
/// sign-out glyph reads against the dark arena.
class _QuitButton extends StatelessWidget {
  const _QuitButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorPalette.surface,
      borderRadius: BorderRadius.circular(RadiusScale.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(SpacingScale.sm),
          child: Icon(
            TtrIcons.signOut,
            size: 24,
            color: ColorPalette.onSurface,
          ),
        ),
      ),
    );
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
