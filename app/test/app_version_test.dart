import 'dart:io';

import 'package:app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_version_matches_pubspec_version', () {
    // Two version sources exist (pubspec + appVersion const); drift
    // between them ships a wrong version to the settings screen.
    // Release discipline: both change in the same commit.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(match!.group(1), appVersion);
  });
}
