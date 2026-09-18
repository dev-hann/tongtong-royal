import 'package:tongtong_shared/src/domain/models.dart';

/// One racer's end-of-round status for timeout ranking.
typedef RaceEntry = ({
  PlayerId id,
  bool finished,
  int finishTick,
  double progressDistance,
});

/// Race ranking rules (GDD § 4.1, § 7.4, § 7.6).
abstract final class RaceRules {
  /// Produces rank groups for a race at round end (or timeout) from
  /// [entries]:
  /// - finishers first, ordered by finish tick ascending; same tick means
  ///   a shared rank (GDD § 7.6);
  /// - unfinished below all finishers, ordered by forward progress
  ///   distance descending (GDD § 7.4); same distance means a shared rank.
  static List<List<PlayerId>> rankOnTimeout(List<RaceEntry> entries) {
    final seen = <PlayerId>{};
    for (final entry in entries) {
      if (!seen.add(entry.id)) {
        throw ArgumentError.value(
          entry.id,
          'entries',
          'duplicate player id in race entries',
        );
      }
    }

    final indexed = [
      for (var i = 0; i < entries.length; i++) (i, entries[i]),
    ]..sort((a, b) {
      final finishedDiff = (b.$2.finished ? 1 : 0) - (a.$2.finished ? 1 : 0);
      if (finishedDiff != 0) return finishedDiff;
      if (a.$2.finished && b.$2.finished) {
        final tickDiff = a.$2.finishTick.compareTo(b.$2.finishTick);
        if (tickDiff != 0) return tickDiff;
      } else if (!a.$2.finished && !b.$2.finished) {
        final distanceDiff = b.$2.progressDistance.compareTo(
          a.$2.progressDistance,
        );
        if (distanceDiff != 0) return distanceDiff;
      }
      return a.$1.compareTo(b.$1);
    });

    bool sameGroup(RaceEntry a, RaceEntry b) {
      if (a.finished != b.finished) return false;
      if (a.finished) return a.finishTick == b.finishTick;
      return a.progressDistance == b.progressDistance;
    }

    final groups = <List<PlayerId>>[];
    var i = 0;
    while (i < indexed.length) {
      var groupEnd = i + 1;
      while (groupEnd < indexed.length &&
          sameGroup(indexed[i].$2, indexed[groupEnd].$2)) {
        groupEnd++;
      }
      groups.add([for (var j = i; j < groupEnd; j++) indexed[j].$2.id]);
      i = groupEnd;
    }
    return groups;
  }
}
