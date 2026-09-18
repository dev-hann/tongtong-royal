import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_placement_list.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// ROUND_RESULTS phase screen: placements and points of one round.
///
/// Pure renderer: rows are displayed exactly as delivered by the
/// domain [RoundResult], in its order — no sorting, no re-scoring.
class RoundResultsScreen extends StatelessWidget {
  /// Creates the results screen.
  const RoundResultsScreen({this.result, super.key});

  /// The domain-judged result of the finished round, if delivered yet.
  final RoundResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const Center(child: Text('Waiting for results...'));
    }
    return ListView(
      padding: const EdgeInsets.all(SpacingScale.lg),
      children: [TtrPlacementList(placements: result.placements)],
    );
  }
}
