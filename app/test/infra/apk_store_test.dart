import 'package:app/infra/apk_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('apkFileName', () {
    test('apkFileName_keepsApkPathSegment', () {
      expect(
        apkFileName(Uri.parse('https://example.com/downloads/app-v2.apk')),
        'app-v2.apk',
      );
    });

    test('apkFileName_fallsBackWhenSegmentIsNotApk', () {
      expect(
        apkFileName(Uri.parse('https://example.com/latest')),
        'tongtong-royal-update.apk',
      );
    });

    test('apkFileName_fallsBackOnEmptyPath', () {
      expect(
        apkFileName(Uri.parse('https://example.com')),
        'tongtong-royal-update.apk',
      );
    });

    test('apkFileName_stripsQueryAndFragment', () {
      expect(
        apkFileName(
          Uri.parse('https://example.com/app.apk?token=1#frag'),
        ),
        'app.apk',
      );
    });
  });
}
