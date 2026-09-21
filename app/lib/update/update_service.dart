import 'dart:async' show Future, TimeoutException;
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io' show IOException;

import 'package:app/update/update_http_client.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

export 'package:app/update/update_http_client.dart';

/// Why a self-update step failed (typed errors — never silent,
/// AGENTS § 6.5).
enum UpdateFailureReason {
  /// No network / connection dropped.
  offline,

  /// The request or the body stream stalled past the timeout.
  timeout,

  /// Non-200 HTTP status.
  httpStatus,

  /// The response body could not be parsed as a GitHub release.
  badResponse,

  /// The release carries no `.apk` asset.
  noApkAsset,

  /// The Android install intent could not be fired.
  installFailed,
}

/// Typed self-update failure (GDD § 8.1, ux-checklist self-update
/// row: "never a dead end" — the UI maps [reason] to a retry row).
final class UpdateException implements Exception {
  /// Creates the typed failure.
  const UpdateException(this.reason, this.message);

  /// Machine-readable failure class.
  final UpdateFailureReason reason;

  /// Human-readable detail for logs.
  final String message;

  @override
  String toString() => 'UpdateException($reason): $message';
}

/// One GitHub release, reduced to what the update row needs.
final class ReleaseInfo {
  /// Creates the release snapshot.
  const ReleaseInfo({
    required this.tag,
    required this.notes,
    required this.apkUrl,
    this.publishedAt,
  });

  /// Release tag (`vX.Y.Z`).
  final String tag;

  /// Release notes body, truncated to the first
  /// [UpdateService.maxNotesLength] characters.
  final String notes;

  /// Browser download URL of the `.apk` asset.
  final Uri apkUrl;

  /// Release publish time, when the API provides one.
  final DateTime? publishedAt;
}

/// Self-update service (GDD § 8.1): GitHub latest-release check,
/// chunked APK download into a caller-owned sink, Android install
/// intent via the `update/install` method channel.
///
/// Purity: file and platform work live behind the two seams — the
/// HTTP [UpdateHttpClient] and the sink callback the caller passes
/// to [downloadApk] — so unit tests fake the boundaries (docs/03
/// § 10.2.8). The production file writer (path_provider cache) is
/// `infra/apk_store.dart`; the platform channel side is
/// `MainActivity.kt`.
class UpdateService {
  /// Creates the service over an injectable [client] and [timeout].
  UpdateService({
    UpdateHttpClient? client,
    this.timeout = defaultTimeout,
  }) : _client = client ?? HttpUpdateHttpClient(),
       _ownsClient = client == null;

  /// Latest-release endpoint (public repo, unauthenticated).
  static const String latestReleaseUrl =
      'https://api.github.com/repos/dev-hann/tongtong-royal/releases/latest';

  /// Method channel firing the Android package-install intent.
  static const MethodChannel installMethodChannel = MethodChannel(
    'update/install',
  );

  /// Default request/stream timeout.
  static const Duration defaultTimeout = Duration(seconds: 20);

  /// Release notes are cut to this length for the row subtitle.
  static const int maxNotesLength = 200;

  /// HTTP seam (tests inject fakes — no network in unit tests,
  /// docs/03 § 10.2.9).
  final UpdateHttpClient _client;
  /// Request/stream timeout (injectable — tests shrink it).
  final Duration timeout;
  final bool _ownsClient;

  /// Fetches and parses the latest GitHub release.
  ///
  /// Throws [UpdateException] with [UpdateFailureReason.offline],
  /// `.timeout`, `.httpStatus`, `.badResponse` or `.noApkAsset`.
  Future<ReleaseInfo> checkLatest() async {
    final response = await _fetch(
      Uri.parse(latestReleaseUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    _requireOk(response, 'release check');
    final text = await _readBody(response, 'release check');
    return _parseRelease(text);
  }

  /// Streams the APK at [url] into [sink] (the caller owns the
  /// bytes — file writing stays out of this service), reporting
  /// cumulative progress as a 0..1 fraction when the size is
  /// advertised. A lying `Content-Length` clamps at 1.0.
  Future<void> downloadApk(
    Uri url, {
    required void Function(List<int> chunk) sink,
    void Function(double fraction)? onProgress,
  }) async {
    final response = await _fetch(url);
    _requireOk(response, 'download');
    final total = response.contentLength;
    var received = 0;
    try {
      // Stream-level stall guard: if no chunk arrives within the
      // timeout window the stream emits a TimeoutException (the
      // fetch-level timeout alone cannot see mid-body stalls).
      final guarded = response.body.timeout(
        timeout,
        onTimeout: (sink) {
          sink.addError(TimeoutException('body stalled', timeout));
        },
      );
      await for (final chunk in guarded) {
        sink(chunk);
        received += chunk.length;
        if (total != null && total > 0 && onProgress != null) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      }
    } on TimeoutException {
      throw UpdateException(
        UpdateFailureReason.timeout,
        'download body stalled after $timeout',
      );
    } on IOException catch (error) {
      throw UpdateException(
        UpdateFailureReason.offline,
        'download stream failed: $error',
      );
    }
  }

  /// Fires the Android system install dialog for the APK at [path]
  /// (the user confirms — the app never silently installs,
  /// ux-checklist self-update row).
  Future<void> install(String path) async {
    try {
      await installMethodChannel.invokeMethod<bool>('install', {
        'path': path,
      });
    } on PlatformException catch (error) {
      throw UpdateException(
        UpdateFailureReason.installFailed,
        'install failed: ${error.code} ${error.message ?? ''}',
      );
    } on MissingPluginException catch (error) {
      throw UpdateException(
        UpdateFailureReason.installFailed,
        'install channel unavailable: $error',
      );
    }
  }

  /// Releases owned resources (the default-created HTTP client).
  void dispose() {
    final client = _client;
    if (_ownsClient && client is HttpUpdateHttpClient) {
      client.close();
    }
  }

  Future<UpdateHttpResponse> _fetch(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    try {
      return await _client.fetch(url, headers: headers).timeout(timeout);
    } on TimeoutException {
      throw UpdateException(
        UpdateFailureReason.timeout,
        'request to $url timed out after $timeout',
      );
    } on IOException catch (error) {
      throw UpdateException(
        UpdateFailureReason.offline,
        'request to $url failed: $error',
      );
    } on http.ClientException catch (error) {
      throw UpdateException(
        UpdateFailureReason.offline,
        'request to $url failed: $error',
      );
    }
  }

  void _requireOk(UpdateHttpResponse response, String step) {
    if (response.status != 200) {
      throw UpdateException(
        UpdateFailureReason.httpStatus,
        '$step returned HTTP ${response.status}',
      );
    }
  }

  Future<String> _readBody(UpdateHttpResponse response, String step) {
    // fold -> decode -> classify: malformed bytes must not leak raw
    // FormatException past the service boundary (typed-errors
    // contract); the timeout catches a stalled (open) stream.
    return response.body
        .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))
        .then((bytes) => utf8.decode(bytes))
        .catchError((Object error) {
          throw UpdateException(
            UpdateFailureReason.badResponse,
            '$step body is not valid UTF-8: $error',
          );
        }, test: (error) => error is FormatException)
        .timeout(timeout)
        .catchError((Object error) {
          throw UpdateException(
            UpdateFailureReason.timeout,
            '$step body stalled after $timeout',
          );
        }, test: (error) => error is TimeoutException);
  }

  ReleaseInfo _parseRelease(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw UpdateException(
        UpdateFailureReason.badResponse,
        'release body is not JSON: $error',
      );
    }
    if (decoded is! Map) {
      throw const UpdateException(
        UpdateFailureReason.badResponse,
        'release body is not a JSON object',
      );
    }
    final tag = decoded['tag_name'];
    if (tag is! String || tag.isEmpty) {
      throw const UpdateException(
        UpdateFailureReason.badResponse,
        'release body carries no tag_name',
      );
    }
    final apkUrl = _findApkAsset(decoded['assets']);
    final notes = decoded['body'];
    final published = decoded['published_at'];
    return ReleaseInfo(
      tag: tag,
      notes: notes is String
          ? (notes.length <= maxNotesLength
                ? notes
                : notes.substring(0, maxNotesLength))
          : '',
      apkUrl: apkUrl,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    );
  }

  Uri _findApkAsset(Object? assets) {
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) {
          continue;
        }
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String && name.endsWith('.apk') && url is String) {
          return Uri.parse(url);
        }
      }
    }
    throw const UpdateException(
      UpdateFailureReason.noApkAsset,
      'release carries no .apk asset',
    );
  }
}
