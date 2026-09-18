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
      children: [
        for (final placement in result.placements)
          ListTile(
            key: ValueKey(placement.playerId),
            leading: Text('#${placement.rank}'),
            title: Text(placement.playerId),
            trailing: Text('${placement.points} pt'),
          ),
      ],
    );
  }
}
