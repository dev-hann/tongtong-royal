import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Rank rows with points; a rank shared by several players is
/// labeled `T-<ordinal>` (e.g. `T-1st`).
///
/// Pure renderer: rows are displayed exactly as delivered by the
/// domain, in the given order — no sorting, no re-scoring.
class TtrPlacementList extends StatelessWidget {
  /// Creates the placement list.
  const TtrPlacementList({required this.placements, super.key});

  /// Placements rendered verbatim, in the given order.
  final List<Placement> placements;

  @override
  Widget build(BuildContext context) {
    final sharedRanks = <int>{
      for (final rank in placements.map((p) => p.rank))
        if (placements.where((p) => p.rank == rank).length > 1) rank,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final placement in placements)
          ListTile(
            key: ValueKey(placement.playerId),
            leading: Text(
              _rankLabel(placement.rank, sharedRanks.contains(placement.rank)),
              style: const TextStyle(
                fontSize: TypeScale.titleSize,
                fontWeight: FontWeight.w700,
                color: ColorPalette.onSurface,
              ),
            ),
            title: Text(
              placement.playerId,
              style: const TextStyle(
                fontSize: TypeScale.bodySize,
                fontWeight: FontWeight.w400,
                color: ColorPalette.onSurface,
              ),
            ),
            trailing: Text(
              '${placement.points} pt',
              style: const TextStyle(
                fontSize: TypeScale.labelSize,
                fontWeight: FontWeight.w600,
                color: ColorPalette.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  static String _rankLabel(int rank, bool shared) =>
      shared ? 'T-${_ordinal(rank)}' : _ordinal(rank);

  static String _ordinal(int rank) => switch (rank) {
    1 => '1st',
    2 => '2nd',
    3 => '3rd',
    _ => '${rank}th',
  };
}
