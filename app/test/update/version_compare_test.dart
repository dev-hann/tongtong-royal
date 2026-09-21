import 'package:app/update/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('equal tags', () {
    test('compare_returnsUpToDate_forIdenticalTags', () {
      expect(
        VersionCompare.compare(current: 'v1.2.3', latestTag: 'v1.2.3'),
        VersionOrder.upToDate,
      );
    });

    test('compare_returnsUpToDate_whenOnlyVPrefixDiffers', () {
      expect(
        VersionCompare.compare(current: '1.2.3', latestTag: 'v1.2.3'),
        VersionOrder.upToDate,
      );
    });

    test('compare_returnsUpToDate_ignoringBuildMetadata', () {
      expect(
        VersionCompare.compare(current: 'v1.2.3+55', latestTag: 'v1.2.3'),
        VersionOrder.upToDate,
      );
    });

    test(
      'compare_returnsUpToDate_ignoringBuildMetadataOnBothSides',
      () {
        expect(
          VersionCompare.compare(current: 'v1.2.3+1', latestTag: 'v1.2.3+99'),
          VersionOrder.upToDate,
        );
      },
    );
  });

  group('each semver field decides the order', () {
    test('compare_majorField_olderLatestMeansCurrentIsNewer', () {
      expect(
        VersionCompare.compare(current: 'v2.0.0', latestTag: 'v1.9.9'),
        VersionOrder.currentIsNewer,
      );
    });

    test('compare_majorField_newerLatestMeansUpdateAvailable', () {
      expect(
        VersionCompare.compare(current: 'v1.9.9', latestTag: 'v2.0.0'),
        VersionOrder.updateAvailable,
      );
    });

    test('compare_minorField_olderLatestMeansCurrentIsNewer', () {
      expect(
        VersionCompare.compare(current: 'v1.3.0', latestTag: 'v1.2.99'),
        VersionOrder.currentIsNewer,
      );
    });

    test('compare_minorField_newerLatestMeansUpdateAvailable', () {
      expect(
        VersionCompare.compare(current: 'v1.2.99', latestTag: 'v1.3.0'),
        VersionOrder.updateAvailable,
      );
    });

    test('compare_patchField_olderLatestMeansCurrentIsNewer', () {
      expect(
        VersionCompare.compare(current: 'v1.2.4', latestTag: 'v1.2.3'),
        VersionOrder.currentIsNewer,
      );
    });

    test('compare_patchField_newerLatestMeansUpdateAvailable', () {
      expect(
        VersionCompare.compare(current: 'v1.2.3', latestTag: 'v1.2.4'),
        VersionOrder.updateAvailable,
      );
    });

    test('compare_majorBeatsMinorAndPatch', () {
      expect(
        VersionCompare.compare(current: 'v2.0.0', latestTag: 'v1.999.999'),
        VersionOrder.currentIsNewer,
      );
      expect(
        VersionCompare.compare(current: 'v1.999.999', latestTag: 'v2.0.0'),
        VersionOrder.updateAvailable,
      );
    });

    test('compare_minorBeatsPatch', () {
      expect(
        VersionCompare.compare(current: 'v1.1.0', latestTag: 'v1.0.999'),
        VersionOrder.currentIsNewer,
      );
      expect(
        VersionCompare.compare(current: 'v1.0.999', latestTag: 'v1.1.0'),
        VersionOrder.updateAvailable,
      );
    });
  });

  group('field sweep (property-style)', () {
    test('compare_sweep_majorBumpLosesToMinorBump', () {
      for (var major = 0; major <= 3; major++) {
        expect(
          VersionCompare.compare(
            current: 'v${major + 1}.0.0',
            latestTag: 'v$major.99.99',
          ),
          VersionOrder.currentIsNewer,
          reason: 'major $major: current must win over the smaller major',
        );
      }
    });

    test('compare_sweep_minorBumpLosesToPatchBump', () {
      for (var minor = 0; minor <= 3; minor++) {
        expect(
          VersionCompare.compare(
            current: 'v1.${minor + 1}.0',
            latestTag: 'v1.$minor.99',
          ),
          VersionOrder.currentIsNewer,
          reason: 'minor $minor: current must win over the smaller minor',
        );
      }
    });

    test('compare_sweep_zeroVersionsAreUpToDateAgainstThemselves', () {
      for (final tag in ['v0.0.0', 'v0.1.0', 'v10.20.30']) {
        expect(
          VersionCompare.compare(current: tag, latestTag: tag),
          VersionOrder.upToDate,
          reason: '$tag against itself must be up to date',
        );
      }
    });
  });

  group('invalid input throws FormatException', () {
    void expectThrows(String current, String latest, String because) {
      expect(
        () => VersionCompare.compare(current: current, latestTag: latest),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(because),
          ),
        ),
        reason: '$current vs $latest must reject: $because',
      );
    }

    test('compare_rejectsEmptyLatestTag', () {
      expectThrows('v1.2.3', '', 'latestTag');
    });

    test('compare_rejectsEmptyCurrent', () {
      expectThrows('', 'v1.2.3', 'current');
    });

    test('compare_rejectsTwoFieldTag', () {
      expectThrows('v1.2.3', 'v1.2', 'latestTag');
    });

    test('compare_rejectsFourFieldTag', () {
      expectThrows('v1.2.3.4', 'v1.2.3', 'current');
    });

    test('compare_rejectsNonNumericField', () {
      expectThrows('v1.2.3', 'v1.x.3', 'latestTag');
    });

    test('compare_rejectsLoneVPrefix', () {
      expectThrows('v', 'v1.2.3', 'current');
    });

    test('compare_rejectsGarbage', () {
      expectThrows('v1.2.3', 'latest', 'latestTag');
    });

    test('compare_rejectsPrereleaseSuffix', () {
      expectThrows('v1.2.3', 'v1.2.3-rc1', 'latestTag');
    });

    test('compare_rejectsNegativeField', () {
      expectThrows('v1.2.-3', 'v1.2.3', 'current');
    });
  });
}
