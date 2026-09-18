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

  String _label(int rank, bool shared) =>
      shared ? 'T-${_ordinal(rank)}' : _ordinal(rank);

  String _ordinal(int rank) => switch (rank) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    _ => '${rank}th',
  };

  @override
  Widget build(BuildContext context) {
    final top = rankings
        .where((placement) => placement.rank <= _maxRank)
        .toList(growable: false);
    final sharedRanks = <int>{
      for (final rank in top.map((p) => p.rank))
        if (top.where((p) => p.rank == rank).length > 1) rank,
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final placement in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label(placement.rank, sharedRanks.contains(placement.rank)),
                ),
                const SizedBox(width: 8),
                Text(placement.playerId),
                const SizedBox(width: 8),
                Text('${placement.points} pt'),
              ],
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: rematchButtonKey,
          onPressed: onRematch,
          child: const Text('Rematch'),
        ),
      ],
    );
  }
}
