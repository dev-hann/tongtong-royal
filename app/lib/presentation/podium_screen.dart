import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_placement_list.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// PODIUM phase screen: top-3 standings and rematch button.
///
/// Pure renderer: ranks, points, and sharing were decided by the
/// domain ([Rankings.finalRanking]); this widget only formats them.
/// A rank shared by several players is labeled `T-<ordinal>`.
class PodiumScreen extends StatelessWidget {
  /// Creates the podium screen.
  const PodiumScreen({required this.rankings, this.onRematch, super.key});

  /// Key of the rematch button (for tests and integration finds).
  static const Key rematchButtonKey = Key('podium_rematch_button');

  /// Final standings, best first; shared ranks repeat.
  final List<Placement> rankings;

  /// Invoked when the players choose a rematch.
  final VoidCallback? onRematch;

  /// Ranks shown on the podium (1st through 3rd).
  static const int _maxRank = 3;

  @override
  Widget build(BuildContext context) {
    final top = rankings
        .where((placement) => placement.rank <= _maxRank)
        .toList(growable: false);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TtrPlacementList(placements: top),
        const SizedBox(height: SpacingScale.xl),
        TtrButton(
          key: rematchButtonKey,
          label: 'Rematch',
          size: TtrButtonSize.large,
          onPressed: onRematch,
        ),
      ],
    );
  }
}
