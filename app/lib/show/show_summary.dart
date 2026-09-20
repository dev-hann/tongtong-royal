import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Terminal outcome of a show the human left by elimination (GDD v2
/// § 7.3): the round the human fell in plus the champions the full
/// headless simulation of the remaining rounds produced. Display
/// names are resolved by the shell (seats live there).
@immutable
final class ShowSummary {
  /// Creates a summary.
  const ShowSummary({
    required this.eliminatedInRound,
    required this.champions,
  });

  /// One-based round index the human was eliminated in.
  final int eliminatedInRound;

  /// Champions of the simulated show (one, or the shared-crown pair,
  /// GDD v2 § 7.2).
  final List<PlayerId> champions;

  @override
  String toString() =>
      'ShowSummary(eliminatedInRound: $eliminatedInRound, '
      'champions: $champions)';
}
