import 'dart:io' show Directory, File;

import 'package:app/update/update_service.dart';
import 'package:path_provider/path_provider.dart';

/// APK filename used when the download URL carries none.
const String fallbackApkFileName = 'tongtong-royal-update.apk';

/// Derives the on-disk APK filename for [url] (its last `.apk`
/// path segment, else [fallbackApkFileName]). Pure — unit-tested.
String apkFileName(Uri url) {
  final segments = url.pathSegments;
  if (segments.isNotEmpty && segments.last.endsWith('.apk')) {
    return segments.last;
  }
  return fallbackApkFileName;
}

/// Production download sink (GDD § 8.1 self-update): streams the
/// APK at [url] into `<cache>/updates/<name>` through the service's
/// chunk seam and returns the written file path. The
/// `update/install` FileProvider path (res/xml/file_paths.xml)
/// mirrors the `updates/` subdirectory — keep them in sync.
///
/// I/O glue: real filesystem + path_provider channel — kept out of
/// unit tests per docs/03 § 10.2.8 (fake the boundary: tests inject
/// their own sink driver around [UpdateService.downloadApk]).
Future<String> downloadApkToFile(
  UpdateService service,
  Uri url, {
  void Function(double fraction)? onProgress,
}) async {
  final cache = await getTemporaryDirectory();
  final updatesDir = Directory('${cache.path}/updates');
  await updatesDir.create(recursive: true);
  final file = File('${updatesDir.path}/${apkFileName(url)}');
  final sink = file.openWrite();
  try {
    await service.downloadApk(
      url,
      sink: sink.add,
      onProgress: onProgress,
    );
    await sink.flush();
  } on Object {
    // Never leave a corrupt partial APK behind for the installer.
    await sink.close();
    if (file.existsSync()) {
      file.deleteSync();
    }
    rethrow;
  }
  await sink.close();
  return file.path;
}
