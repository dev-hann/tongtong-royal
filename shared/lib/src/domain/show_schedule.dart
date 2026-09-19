import 'package:meta/meta.dart';

import 'package:tongtong_shared/src/domain/models.dart';

/// One round slot of the show (GDD § 4 table).
@immutable
final class ShowSlot {
  /// Creates a slot.
  const ShowSlot({
    required this.roundIndex,
    required this.gameId,
    required this.quota,
    required this.isFinal,
  });

  /// One-based position of the round in the show (1..3).
  final int roundIndex;

  /// The minigame running in this slot.
  final MiniGameId gameId;

  /// How many players qualify from this round.
  final int quota;

  /// Whether this slot is the FINAL (crown round).
  final bool isFinal;

  @override
  String toString() =>
      'ShowSlot($roundIndex, $gameId, quota: $quota, final: $isFinal)';
}

/// The fixed show structure: which game runs in which slot, each
/// slot's quota, the starter-count cascade tolerances, and the
/// keyed map-seed stream (GDD § 4, § 6). A value object — no
/// runtime state lives here.
final class ShowSchedule {
  const ShowSchedule._(this._slots);

  /// The standard show (GDD § 4): Trap Race R1 (4 players, quota
  /// 3), Hammer Dodge R2 (3 players, quota 2), Trap Race FINAL
  /// (2 players, quota 1 — the crown).
  static const ShowSchedule standard = ShowSchedule._([
    ShowSlot(roundIndex: 1, gameId: 'trap_race', quota: 3, isFinal: false),
    ShowSlot(roundIndex: 2, gameId: 'hammer_dodge', quota: 2, isFinal: false),
    ShowSlot(roundIndex: 3, gameId: 'trap_race', quota: 1, isFinal: true),
  ]);

  /// Rounds per show (GDD § 1: exactly 3).
  static const int roundCount = 3;

  /// Fixed first-round field: solo shows fill to 4 seats (GDD § 9).
  static const int firstRoundField = 4;

  final List<ShowSlot> _slots;

  /// The slots in show order.
  List<ShowSlot> get slots => List.unmodifiable(_slots);

  /// Returns the slot for [roundIndex] (1-based).
  ///
  /// Throws [ArgumentError] outside 1..[roundCount].
  ShowSlot slotFor(int roundIndex) {
    _checkRoundIndex(roundIndex);
    return _slots[roundIndex - 1];
  }

  /// Derives the starter count of [roundIndex] from the previous
  /// round's qualified list (GDD § 4 cascade note: every spec
  /// tolerates one extra starter beyond its nominal row).
  ///
  /// Round 1 starts from the fixed [firstRoundField] and takes no
  /// previous verdict. Rounds 2+ accept only counts inside their
  /// tolerance (R2: 3-4, FINAL: 2-4); anything else throws
  /// [ArgumentError] — the quota rules guarantee it can never
  /// happen in a real show.
  int starterCountFor(int roundIndex, {List<PlayerId>? previousQualified}) {
    _checkRoundIndex(roundIndex);
    if (roundIndex == 1) {
      if (previousQualified != null) {
        throw ArgumentError.value(
          previousQualified,
          'previousQualified',
          'round 1 starts from the fixed show field',
        );
      }
      return firstRoundField;
    }
    final qualified = previousQualified;
    if (qualified == null) {
      throw ArgumentError.notNull('previousQualified');
    }
    final count = qualified.length;
    final tolerated = switch (roundIndex) {
      2 => (min: 3, max: 4),
      _ => (min: 2, max: 4),
    };
    if (count < tolerated.min || count > tolerated.max) {
      throw ArgumentError.value(
        count,
        'previousQualified',
        'round $roundIndex accepts '
        '${tolerated.min}-${tolerated.max} starters',
      );
    }
    return count;
  }

  /// Derives the round's map seed from the show seed (GDD § 6):
  /// `mapSeed = stream(showSeed, roundIndex)` via a keyed RNG
  /// stream — a splitmix64-style keyed mix, never literal
  /// addition, so `(showSeed, roundIndex)` pairs never collide
  /// across shows. Deterministic and pure; the app and host share
  /// this one function.
  static int mapSeedFor({required int showSeed, required int roundIndex}) {
    _checkRoundIndex(roundIndex);
    final showKey = _mix64(showSeed ^ _showKeyStreamConst);
    return _mix64(showKey + roundIndex * _roundKeyStride) & 0x7FFFFFFF;
  }

  static void _checkRoundIndex(int roundIndex) {
    if (roundIndex < 1 || roundIndex > roundCount) {
      throw ArgumentError.value(
        roundIndex,
        'roundIndex',
        'must be within 1..$roundCount',
      );
    }
  }
}

/// Golden-ratio increment constant of the splitmix64 finalizer.
// 64-bit literals and multiply-mixing are VM/AOT-only by design:
// `shared` runs on the Dart VM (server) and Flutter mobile AOT;
// web is not a release target (arch § 1).
// ignore: avoid_js_rounded_ints
const int _showKeyStreamConst = 0x9E3779B97F4A7C15;

/// Large odd stride keeping per-round streams apart.
const int _roundKeyStride = 0x9E3779B1;

/// splitmix64 finalizer (Steele et al.): avalanche-mixes a 64-bit
/// word so nearby inputs land far apart.
// ignore: avoid_js_rounded_ints
int _mix64(int z) {
  var mixed = z;
  // ignore: avoid_js_rounded_ints
  mixed = (mixed ^ (mixed >>> 30)) * 0xBF58476D1CE4E5B9;
  // ignore: avoid_js_rounded_ints
  mixed = (mixed ^ (mixed >>> 27)) * 0x94D049BB133111EB;
  return mixed ^ (mixed >>> 31);
}
