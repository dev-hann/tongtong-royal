import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_placement_list.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_RESULTS phase screen: header pill, round placements,
/// cumulative standings with this round's deltas, and an auto-advance
/// progress bar over the dwell window.
///
/// Pure renderer: rows are displayed exactly as delivered by the
/// domain [RoundResult], standings exactly as computed by the
/// controller (domain [Rankings] calls) — no sorting, no re-scoring.
/// The progress bar mirrors the host-owned auto-advance timer; it
/// never triggers the transition itself.
class RoundResultsScreen extends StatelessWidget {
  /// Creates the results screen.
  const RoundResultsScreen({
    this.result,
    this.roundNumber,
    this.totalRounds,
    this.minigameName,
    this.standings = const [],
    this.autoAdvanceSeconds,
    super.key,
  });

  /// Key of the header pill (for tests and integration finds).
  static const Key headerKey = Key('round_results_header');

  /// Key of the auto-advance progress bar (for tests).
  static const Key autoAdvanceKey = Key('round_results_auto_advance');

  /// The domain-judged result of the finished round, if delivered yet.
  final RoundResult? result;

  /// 1-based round number for the header pill.
  final int? roundNumber;

  /// Total rounds in the match for the header pill.
  final int? totalRounds;

  /// Display name of the round's minigame; hidden when empty.
  final String? minigameName;

  /// Cumulative standings (controller-computed), best first.
  final List<StandingEntry> standings;

  /// Dwell window the host uses before auto-advancing; drives the
  /// progress bar. `null` hides the bar.
  final int? autoAdvanceSeconds;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const Center(child: Text('Waiting for results...'));
    }
    return Stack(
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
                if (autoAdvanceSeconds case final seconds?) ...[
                  const SizedBox(height: SpacingScale.lg),
                  _AutoAdvanceBar(seconds: seconds),
                ],
              ],
            ),
          ),
        ),
      ],
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

/// One-shot progress bar over the auto-advance dwell window.
class _AutoAdvanceBar extends StatefulWidget {
  const _AutoAdvanceBar({required this.seconds});

  final int seconds;

  @override
  State<_AutoAdvanceBar> createState() => _AutoAdvanceBarState();
}

class _AutoAdvanceBarState extends State<_AutoAdvanceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  )..forward();

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) => LinearProgressIndicator(
        key: RoundResultsScreen.autoAdvanceKey,
        value: _progress.isCompleted ? null : _progress.value,
        minHeight: SpacingScale.sm,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        backgroundColor: ColorPalette.neutral200,
        valueColor: const AlwaysStoppedAnimation<Color>(
          ColorPalette.primary,
        ),
      ),
    );
  }
}
