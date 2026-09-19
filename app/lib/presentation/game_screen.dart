import 'dart:async';

import 'package:app/design/game_hud/score_entry.dart';
import 'package:app/design/game_hud/ttr_score_strip.dart';
import 'package:app/design/game_hud/ttr_timer_badge.dart';
import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

export 'package:app/design/game_hud/score_entry.dart' show ScoreEntry;

/// ROUND_PLAY phase shell: HUD chrome around the Flame game viewport.
///
/// Pure renderer: scores, round number and the timer seed are
/// injected values (host-owned, architecture doc § 4). Between
/// rebuilds the timer badge ticks down locally at 1 Hz (display-only;
/// the authoritative round end comes from the host/driver, never
/// from this clock). The Flame widget is mounted by the game layer
/// through [gameView] — this screen holds no game logic.
class GameScreen extends StatelessWidget {
  /// Creates the game screen shell.
  const GameScreen({
    required this.scoreboard,
    required this.timeRemaining,
    this.remainingSeconds,
    this.roundNumber,
    this.totalRounds,
    this.gameView,
    super.key,
  });

  /// Key of the game viewport slot (for tests and integration finds).
  static const Key gameViewportKey = Key('game_viewport');

  /// Key of the HUD timer text (for tests and integration finds).
  static const Key timerKey = Key('game_timer');

  /// Cumulative score strip entries, injected.
  final List<ScoreEntry> scoreboard;

  /// Timer text (e.g. seconds left), injected from host state; used
  /// verbatim when [remainingSeconds] is null.
  final String timeRemaining;

  /// Seed for the live timer badge (seconds); when non-null it wins
  /// over [timeRemaining] and ticks down locally.
  final int? remainingSeconds;

  /// 1-based round number for the HUD round chip.
  final int? roundNumber;

  /// Total rounds in the match for the HUD round chip.
  final int? totalRounds;

  /// Slot where the game layer mounts the Flame widget.
  final Widget? gameView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(SpacingScale.sm),
          child: TtrScoreStrip(
            entries: scoreboard,
            roundNumber: roundNumber,
            totalRounds: totalRounds,
          ),
        ),
        Expanded(
          child:
              gameView ??
              ColoredBox(
                key: gameViewportKey,
                color: const ArenaPalette().background,
                child: const Center(child: Text('Game placeholder')),
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(SpacingScale.sm),
          child: _HudTimer(
            key: timerKey,
            label: timeRemaining,
            remainingSeconds: remainingSeconds,
          ),
        ),
      ],
    );
  }
}

/// Timer badge fed by an injected seed, ticking down at 1 Hz purely
/// for display; re-seeds whenever the injected value changes.
class _HudTimer extends StatefulWidget {
  const _HudTimer({required this.label, this.remainingSeconds, super.key});

  /// Host-owned label used when [remainingSeconds] is null.
  final String label;

  /// Injected seconds seed; `null` renders [label] verbatim.
  final int? remainingSeconds;

  @override
  State<_HudTimer> createState() => _HudTimerState();
}

class _HudTimerState extends State<_HudTimer> {
  Timer? _ticker;
  late int _seconds = widget.remainingSeconds ?? 0;

  @override
  void didUpdateWidget(_HudTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _seconds = widget.remainingSeconds ?? 0;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicking() {
    if (_ticker != null || widget.remainingSeconds == null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _seconds <= 0) {
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureTicking();
    return TtrTimerBadge(
      timeLabel: widget.remainingSeconds == null
          ? widget.label
          : '$_seconds',
    );
  }
}
