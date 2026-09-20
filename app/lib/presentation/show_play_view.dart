import 'dart:async' show unawaited;

import 'package:app/design/game_hud/ttr_action_button.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_quit_dialog.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/arenas/hammer/hammer_simulation.dart';
import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/auto_input_source.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/hammer_game_view.dart';
import 'package:app/game/view/race_game_view.dart'
    show RaceGameView, maxStepsPerFrame;
import 'package:app/infra/sound_service.dart';
import 'package:app/show/show_round_session.dart';
import 'package:flame/game.dart' show Game, GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_PLAY widget for a show round: mounts the session's
/// simulation with the human on the one-button controls (GDD v2 § 3:
/// automatic movement + a single verb button) and the session's bot
/// brains feeding the view's tick-inputs provider.
///
/// Race rounds render through [RaceGameView], Hammer Dodge through
/// [HammerGameView] — both draw jelly players (guide § 9.1). Wiring
/// only — judging stays in the driver's domain resolve; timers only
/// here in the widget layer.
final class ShowPlayView extends StatefulWidget {
  /// Creates the view over [session].
  const ShowPlayView({
    required this.session,
    this.seatColors = const {},
    this.sound,
    this.onQuit,
    super.key,
  });

  /// Key of the one-button action control (tests).
  static const Key actionButtonKey = Key('show_action_button');

  /// Key of the top-right round-quit button (tests).
  static const Key quitButtonKey = Key('show_quit_button');

  /// The round to mount (from the show controller's current round).
  final ShowRoundSession session;

  /// Seat colors per player (a `PlayerPalette` value each).
  final Map<PlayerId, Color> seatColors;

  /// Fired when the player confirms the mid-round quit dialog
  /// (GDD v2 § 7.4): the shell abandons the show back to home.
  final VoidCallback? onQuit;

  /// Sound cue hook for the action button (null in tests).
  final SoundService? sound;

  @override
  State<ShowPlayView> createState() => _ShowPlayViewState();
}

final class _ShowPlayViewState extends State<ShowPlayView> {
  late final ActionInputController _controller = ActionInputController();

  Game? _game;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final humanId = session.humanId;
    if (humanId != null) {
      session.driver.humanInput = AutoInputSource(
        gameId: session.minigameId,
        controller: _controller,
        simulation: session.simulation,
        humanId: humanId,
        roster: session.rosterIds,
      );
    }
    _game = _buildGame(session);
  }

  Game? _buildGame(ShowRoundSession session) {
    final simulation = session.simulation;
    final map = session.map;
    if (simulation is RaceSimulation &&
        map is CourseMap &&
        session.humanId != null) {
      return RaceGameView(
        simulation: simulation,
        localPlayerId: session.humanId!,
        map: map,
        playerIds: session.rosterIds,
        playerColors: widget.seatColors,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
      )..onStep = session.driver.postTick;
    }
    if (simulation is HammerSimulation && map is HammerArenaMap) {
      return HammerGameView(
        simulation: simulation,
        localPlayerId: session.humanId ?? session.rosterIds.first,
        map: map,
        playerIds: session.rosterIds,
        playerColors: widget.seatColors,
        tickInputsProvider: session.driver.buildInputs,
        tickEnabled: () => !session.isOver,
      )..onStep = session.driver.postTick;
    }
    return null;
  }

  @override
  void dispose() {
    if (_game case final RaceGameView race) {
      race.onRemove();
    }
    super.dispose();
  }

  /// The one-button press: jump cue + input edge (GDD v2 § 3).
  void _pressAction() {
    widget.sound?.play(Sfx.jump);
    _controller.press();
  }

  /// Quit confirm (GDD v2 § 7.4): QUIT fires [ShowPlayView.onQuit];
  /// every other dismissal keeps the show running.
  Future<void> _confirmQuit() async {
    final quit = await TtrQuitDialog.show(context);
    if (quit && mounted) {
      widget.onQuit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // System back is intercepted behind the same quit confirm as
    // the exit button — back never silently abandons the show.
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
                key: ShowPlayView.quitButtonKey,
                onPressed: _confirmQuit,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              // Respect the bottom system-inset (gesture area) on top
              // of the visual margin (guide § 8).
              bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
              child: Center(
                child: TtrActionButton(
                  key: ShowPlayView.actionButtonKey,
                  label: switch (
                    ActionInputController.verbFor(widget.session.minigameId)) {
                    GameVerb.jump => 'JUMP',
                    GameVerb.dash => 'DASH',
                  },
                  onPressed: _pressAction,
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

/// Top-right round exit affordance: surface chip so the sign-out
/// glyph reads against the dark arena.
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

/// Fallback for round mountings whose sim/map types have no renderer
/// yet (defensive): a frame ticker drives the session's fixed-dt
/// ticks headlessly (same accumulator policy as the game views) over
/// a dark status pane — the round stays honest even without a view.
final class _HeadlessRoundPane extends StatefulWidget {
  const _HeadlessRoundPane({required this.session});

  final ShowRoundSession session;

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
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const ArenaPalette().background,
      child: const Center(
        child: Text('Round is running — rendering unavailable.'),
      ),
    );
  }
}
