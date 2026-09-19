import 'package:meta/meta.dart';

import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';

/// Per-round qualification verdict (GDD v2 § 2, arch § 3).
///
/// Qualification is binary: each player is in [qualified] or in
/// [eliminated]. Shared qualification (GDD § 7.1) can make
/// [qualified] one player longer than the quota.
@immutable
final class QualificationResult {
  /// Creates a verdict.
  const QualificationResult({
    required this.qualified,
    required this.eliminated,
    required this.isFinal,
    this.champions = const [],
  });

  /// Players who advance, best first (finish order for races,
  /// survivors then crossing victims for survival games).
  final List<PlayerId> qualified;

  /// Players who are out of the show, in elimination order.
  final List<PlayerId> eliminated;

  /// Whether this round was the FINAL (crown round).
  final bool isFinal;

  /// Crown winners; empty unless [isFinal]. Exactly one, or the
  /// shared-crown group (GDD § 7.2 — every member gets the crown).
  final List<PlayerId> champions;

  @override
  bool operator ==(Object other) =>
      other is QualificationResult &&
      _listEquals(other.qualified, qualified) &&
      _listEquals(other.eliminated, eliminated) &&
      other.isFinal == isFinal &&
      _listEquals(other.champions, champions);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(qualified),
    Object.hashAll(eliminated),
    isFinal,
    Object.hashAll(champions),
  );

  @override
  String toString() =>
      'QualificationResult(qualified: $qualified, '
      'eliminated: $eliminated, isFinal: $isFinal, '
      'champions: $champions)';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Qualification-era minigame contract (GDD v2, arch § 3).
///
/// Transitional shape (documented in arch § 3): the v1
/// `MiniGame.resolve` placements path stays for the live v1 shell;
/// v2 show runtimes call [resolveQualification]. The quota, FINAL
/// flag, and roster travel ON `RoundEvents` (arch § 3 event
/// channel); the optional input parameter carries per-minigame
/// continuous data (e.g. `TrapRaceInput.progressSamples`) and must
/// be each game's own input type or null.
abstract interface class QualificationGame implements MiniGame {
  /// Decides the round's qualification verdict from ordered events.
  ///
  /// Throws [ArgumentError] when [RoundEvents.quota] is missing or
  /// below one, when the field (roster plus event players) is
  /// empty, when the round carries no observable data at all, or
  /// when [input] is not this game's input type.
  QualificationResult resolveQualification(RoundEvents events, [Object? input]);
}
