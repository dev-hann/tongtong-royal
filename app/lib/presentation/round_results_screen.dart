import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_placement_list.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_RESULTS phase screen (terminal, GDD § 5): header pill,
/// round placements, standings with this round's deltas, and the
/// two ending actions — PLAY AGAIN (fresh match) and HOME.
///
/// Pure renderer: rows are displayed exactly as delivered by the
/// domain [RoundResult], standings exactly as computed by the
/// controller (domain [Rankings] calls) — no sorting, no re-scoring,
/// no timers: the single-round match ends here and the buttons
/// carry the shell transitions.
class RoundResultsScreen extends StatelessWidget {
  /// Creates the results screen.
  const RoundResultsScreen({
    this.result,
    this.roundNumber,
    this.totalRounds,
    this.minigameName,
    this.standings = const [],
    this.onPlayAgain,
    this.onExitHome,
    super.key,
  });

  /// Key of the header pill (for tests and integration finds).
  static const Key headerKey = Key('round_results_header');

  /// Key of the PLAY AGAIN button (for tests and integration finds).
  static const Key playAgainButtonKey = Key('round_results_play_again');

  /// Key of the HOME button (for tests and integration finds).
  static const Key exitHomeButtonKey = Key('round_results_exit_home');

  /// The domain-judged result of the finished round, if delivered yet.
  final RoundResult? result;

  /// 1-based round number for the header pill.
  final int? roundNumber;

  /// Total rounds in the match for the header pill.
  final int? totalRounds;

  /// Display name of the round's minigame; hidden when empty.
  final String? minigameName;

  /// Standings (controller-computed), best first.
  final List<StandingEntry> standings;

  /// Starts a fresh match (new map seed).
  final VoidCallback? onPlayAgain;

  /// Returns to the shell's home screen.
  final VoidCallback? onExitHome;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const Center(child: Text('Waiting for results...'));
    }
    // System back on the terminal screen = HOME (GDD § 5), never a
    // silent app exit.
    return PopScope(
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
              child: ListView(
                padding: const EdgeInsets.all(SpacingScale.lg),
                children: [
                  Center(
                    // The header pill is the screen's one pulsing
                    // element (guide § 4): the "active round" badge.
                    child: TtrPulse(
                      child: _HeaderPill(text: _headerLabel(result)),
                    ),
                  ),
                  const SizedBox(height: SpacingScale.lg),
                  TtrPlacementList(placements: result.placements),
                  if (standings.isNotEmpty) ...[
                    const SizedBox(height: SpacingScale.xl),
                    Text(
                      'Standings',
                      textAlign: TextAlign.center,
                      style: TypeScale.bodyLabel.copyWith(
                        color: ColorPalette.neutral500,
                      ),
                    ),
                    TtrStandingsList(entries: standings),
                  ],
                  const SizedBox(height: SpacingScale.xl),
                  _ResultActions(
                    onPlayAgain: onPlayAgain,
                    onExitHome: onExitHome,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _headerLabel(RoundResult result) {
    final round = roundNumber ?? result.roundIndex + 1;
    final total = totalRounds == null ? '$round' : '$totalRounds';
    final name = (minigameName ?? '').toUpperCase();
    final roundPart = 'ROUND $round / $total';
    return name.isEmpty ? roundPart : '$roundPart · $name';
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: RoundResultsScreen.headerKey,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        border: Border.all(color: ColorPalette.neutral200),
      ),
      child: Text(text, style: TypeScale.label),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({this.onPlayAgain, this.onExitHome});

  final VoidCallback? onPlayAgain;
  final VoidCallback? onExitHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TtrButton(
          key: RoundResultsScreen.playAgainButtonKey,
          label: 'PLAY AGAIN',
          onPressed: onPlayAgain,
        ),
        const SizedBox(height: SpacingScale.md),
        TtrButton(
          key: RoundResultsScreen.exitHomeButtonKey,
          label: 'HOME',
          variant: TtrButtonVariant.secondary,
          onPressed: onExitHome,
        ),
      ],
    );
  }
}
