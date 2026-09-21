/// Ordering verdict of the self-update version check (GDD § 8.1).
enum VersionOrder {
  /// Current build matches the latest release tag.
  upToDate,

  /// The latest release tag is newer than the current build.
  updateAvailable,

  /// The current build is newer than the latest release tag.
  currentIsNewer,
}

/// Compares `v`-prefixed semver strings for the self-update row.
///
/// Accepted shape: optional `v` prefix, `MAJOR.MINOR.PATCH`, optional
/// `+build` metadata (ignored — equal cores are equal versions).
/// Anything else is a [FormatException] naming the offending input.
abstract final class VersionCompare {
  static final RegExp _tagPattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:\+[0-9A-Za-z.-]+)?$',
  );

  /// Orders [current] against [latestTag] (docs/03 § 9 update-row).
  static VersionOrder compare({
    required String current,
    required String latestTag,
  }) {
    final currentFields = _parse(current, 'current');
    final latestFields = _parse(latestTag, 'latestTag');
    for (var i = 0; i < 3; i++) {
      final order = currentFields[i].compareTo(latestFields[i]);
      if (order != 0) {
        return order < 0
            ? VersionOrder.updateAvailable
            : VersionOrder.currentIsNewer;
      }
    }
    return VersionOrder.upToDate;
  }

  static List<int> _parse(String tag, String inputName) {
    final match = _tagPattern.matchAsPrefix(tag);
    if (match == null) {
      throw FormatException(
        'invalid $inputName "$tag": expected vX.Y.Z (+build metadata '
        'optional, prerelease suffixes unsupported)',
      );
    }
    return [
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    ];
  }
}
