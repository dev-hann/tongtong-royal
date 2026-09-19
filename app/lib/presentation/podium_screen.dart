import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/presentation/podium_pedestal.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// PODIUM phase screen: real pedestals (2nd / 1st / 3rd), celebration
/// pulse on 1st, chips for 4th+, rematch + exit actions.
///
/// Pure renderer: ranks, points, and sharing were decided by the
/// domain ([Rankings.finalRanking]); this widget only formats them.
/// A rank shared by several players is labeled `T-<ordinal>` and all
/// sharers stand on the same pedestal.
class PodiumScreen extends StatelessWidget {
  /// Creates the podium screen.
  const PodiumScreen({
    required this.rankings,
    this.nicknames = const {},
    this.playerColors = const {},
    this.onRematch,
    this.onExit,
    super.key,
  });

  /// Key of the rematch button (for tests and integration finds).
  static const Key rematchButtonKey = Key('podium_rematch_button');

  /// Key of the exit-to-home button (for tests and integration finds).
  static const Key exitButtonKey = Key('podium_exit_button');

  /// Key of the 1st-place pedestal block (for tests).
  static const Key firstPedestalKey = Key('podium_first_pedestal');

  /// Key of the 2nd-place pedestal block (for tests).
  static const Key secondPedestalKey = Key('podium_second_pedestal');

  /// Key of the 3rd-place pedestal block (for tests).
  static const Key thirdPedestalKey = Key('podium_third_pedestal');

  /// Key of the 1st-place trophy icon (for tests).
  static const Key trophyKey = trophyIconKey;

  /// Key of the below-podium chips (rank 4+, one per player).
  static const Key fourthChipKey = Key('podium_fourth_chip');

  /// 1st-place pedestal height (spacing-scale multiple).
  static const double firstHeight = SpacingScale.xxxl * 4;

  /// 2nd-place pedestal height (spacing-scale multiple).
  static const double secondHeight = SpacingScale.xxxl * 3;

  /// 3rd-place pedestal height (spacing-scale multiple).
  static const double thirdHeight = SpacingScale.xxxl * 2;

  /// Final standings, best first; shared ranks repeat.
  final List<Placement> rankings;

  /// Optional display names by player id (falls back to the id).
  final Map<String, String> nicknames;

  /// Optional seat colors by player id (falls back to the seat
  /// palette by rank slot).
  final Map<String, Color> playerColors;

  /// Invoked when the players choose a rematch.
  final VoidCallback? onRematch;

  /// Invoked when the players exit to the home screen.
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final byRank = <int, List<Placement>>{};
    for (final placement in rankings) {
      if (placement.rank <= 3) {
        byRank.putIfAbsent(placement.rank, () => []).add(placement);
      }
    }
    final rest = rankings
        .where((placement) => placement.rank > 3)
        .toList(growable: false);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ColorPalette.warningSoft, ColorPalette.background],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PodiumPedestal(
                      blockKey: secondPedestalKey,
                      placements: byRank[2] ?? const [],
                      height: secondHeight,
                      nicknames: nicknames,
                      playerColors: playerColors,
                    ),
                    const SizedBox(width: SpacingScale.md),
                    PodiumPedestal(
                      blockKey: firstPedestalKey,
                      placements: byRank[1] ?? const [],
                      height: firstHeight,
                      trophy: true,
                      pulse: true,
                      nicknames: nicknames,
                      playerColors: playerColors,
                    ),
                    const SizedBox(width: SpacingScale.md),
                    PodiumPedestal(
                      blockKey: thirdPedestalKey,
                      placements: byRank[3] ?? const [],
                      height: thirdHeight,
                      nicknames: nicknames,
                      playerColors: playerColors,
                    ),
                  ],
                ),
              ),
            ),
            if (rest.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: SpacingScale.md),
                child: Wrap(
                  spacing: SpacingScale.sm,
                  runSpacing: SpacingScale.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final placement in rest)
                      _FourthChip(
                        placement: placement,
                        nickname:
                            nicknames[placement.playerId] ??
                            placement.playerId,
                      ),
                  ],
                ),
              ),
            TtrButton(
              key: rematchButtonKey,
              label: 'Rematch',
              size: TtrButtonSize.large,
              onPressed: onRematch,
            ),
            const SizedBox(height: SpacingScale.sm),
            TtrButton(
              key: exitButtonKey,
              label: 'Exit',
              variant: TtrButtonVariant.secondary,
              onPressed: onExit,
            ),
            const SizedBox(height: SpacingScale.lg),
          ],
        ),
      ),
    );
  }
}

class _FourthChip extends StatelessWidget {
  const _FourthChip({required this.placement, required this.nickname});

  final Placement placement;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: PodiumScreen.fourthChipKey,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.md,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        border: Border.all(color: ColorPalette.neutral200),
      ),
      child: Text(
        '${ordinalOf(placement.rank)} · $nickname',
        style: const TextStyle(
          fontSize: TypeScale.labelSize,
          fontWeight: FontWeight.w600,
          color: ColorPalette.neutral700,
        ),
      ),
    );
  }
}
