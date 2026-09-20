import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';

/// Elimination summary screen (GDD v2 § 7.3 — the one screen exempt
/// from the Form Law, guide § 6): the human is out. Own verdict for
/// the round they fell in, the simulated show outcome (which bot
/// takes the crown — one line), stat deltas, and the two terminal
/// actions: PLAY AGAIN primary + HOME secondary.
///
/// Pure renderer: all copy arrives as data from the show runtime —
/// the headless simulation already resolved the outcome.
class EliminationSummaryScreen extends StatelessWidget {
  /// Creates the summary.
  const EliminationSummaryScreen({
    required this.eliminatedInRound,
    required this.championLine,
    this.statDeltas = const [],
    this.onPlayAgain,
    this.onExitHome,
    super.key,
  });

  /// Key of the verdict line (tests and integration finds).
  static const Key verdictKey = Key('elimination_summary_verdict');

  /// Key of the PLAY AGAIN button (tests and integration finds).
  static const Key playAgainButtonKey = Key('elimination_play_again');

  /// Key of the HOME button (tests and integration finds).
  static const Key exitHomeButtonKey = Key('elimination_exit_home');

  /// 1-based round the human was eliminated in.
  final int eliminatedInRound;

  /// One line naming the simulated show's champion, e.g.
  /// `BOT 2 takes the crown`.
  final String championLine;

  /// Stat delta chips, e.g. `SHOWS +1` (GDD v2 § 7.3 stat deltas).
  final List<String> statDeltas;

  /// Starts a fresh show (GDD v2 § 1 PLAY AGAIN).
  final VoidCallback? onPlayAgain;

  /// Returns to the home screen (GDD v2 § 1 HOME).
  final VoidCallback? onExitHome;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Terminal screen: back = HOME (ux-checklist back matrix).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onExitHome?.call();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TtrAmbientBackdrop(),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ColorPalette.secondarySoft, ColorPalette.background],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ELIMINATED IN ROUND $eliminatedInRound',
                      key: verdictKey,
                      style: TypeScale.title.copyWith(
                        color: ColorPalette.danger,
                      ),
                    ),
                    const SizedBox(height: SpacingScale.lg),
                    Text(championLine, style: TypeScale.body),
                    if (statDeltas.isNotEmpty) ...[
                      const SizedBox(height: SpacingScale.lg),
                      for (final (index, delta) in statDeltas.indexed)
                        TtrStaggeredEntrance(
                          index: index,
                          child: _StatDeltaChip(delta: delta),
                        ),
                    ],
                    const SizedBox(height: SpacingScale.xxxl),
                    TtrButton(
                      key: playAgainButtonKey,
                      label: 'PLAY AGAIN',
                      onPressed: onPlayAgain,
                    ),
                    const SizedBox(height: SpacingScale.md),
                    TtrButton(
                      key: exitHomeButtonKey,
                      label: 'HOME',
                      variant: TtrButtonVariant.secondary,
                      onPressed: onExitHome,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDeltaChip extends StatelessWidget {
  const _StatDeltaChip({required this.delta});

  final String delta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingScale.xs / 2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingScale.md,
          vertical: SpacingScale.xs,
        ),
        decoration: BoxDecoration(
          color: ColorPalette.surface,
          borderRadius: BorderRadius.circular(RadiusScale.chip),
          border: Border.all(color: ColorPalette.neutral200),
        ),
        child: Text(delta, style: TypeScale.bodyLabel),
      ),
    );
  }
}
