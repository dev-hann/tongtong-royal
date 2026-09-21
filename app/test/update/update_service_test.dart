import 'dart:async' show Completer;
import 'dart:convert' show jsonEncode, utf8;
import 'dart:io' show SocketException;

import 'package:app/update/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scriptable [UpdateHttpClient] — no real network (docs/03 § 10.2.9).
final class FakeUpdateHttpClient implements UpdateHttpClient {
  FakeUpdateHttpClient(this.handler);

  FakeUpdateHttpClient.json(String body, {int status = 200})
    : handler =
          ((Uri url, {Map<String, String>? headers}) async =>
              UpdateHttpResponse(
                status: status,
                contentLength: utf8.encode(body).length,
                body: Stream<List<int>>.value(utf8.encode(body)),
              ));

  final Future<UpdateHttpResponse> Function(
    Uri url, {
    Map<String, String>? headers,
  })
  handler;

  final List<Uri> requestedUrls = [];

  @override
  Future<UpdateHttpResponse> fetch(
    Uri url, {
    Map<String, String>? headers,
  }) {
    requestedUrls.add(url);
    return handler(url, headers: headers);
  }
}

String releaseJson({
  String tag = 'v0.2.0',
  String body = 'Bug fixes and polish.',
  String? publishedAt = '2026-09-01T10:00:00Z',
  String assets = '''
    {"name": "app-arm64.apk",
     "browser_download_url": "https://example.com/app-arm64.apk"}''',
}) =>
    '''
{"tag_name": "$tag", "body": ${jsonEncode(body)},
 "published_at": ${publishedAt == null ? 'null' : '"$publishedAt"'},
 "assets": [$assets]}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UpdateService serviceWith(FakeUpdateHttpClient client) =>
      UpdateService(client: client);

  group('checkLatest happy path', () {
    test('checkLatest_parsesTagNotesApkUrlAndPublishDate', () async {
      final client = FakeUpdateHttpClient.json(releaseJson());
      final service = serviceWith(client);

      final release = await service.checkLatest();

      expect(release.tag, 'v0.2.0');
      expect(release.notes, 'Bug fixes and polish.');
      expect(
        release.apkUrl.toString(),
        'https://example.com/app-arm64.apk',
      );
      expect(release.publishedAt, DateTime.parse('2026-09-01T10:00:00Z'));
      expect(
        client.requestedUrls,
        [Uri.parse(UpdateService.latestReleaseUrl)],
        reason: 'must query the pinned latest-release endpoint',
      );
    });

    test('checkLatest_usesGitHubJsonAcceptHeader', () async {
      Map<String, String>? seen;
      final client = FakeUpdateHttpClient(
        (url, {headers}) async {
          seen = headers;
          return UpdateHttpResponse(
            status: 200,
            body: Stream<List<int>>.value(
              utf8.encode(releaseJson()),
            ),
          );
        },
      );

      await serviceWith(client).checkLatest();

      expect(
        seen,
        containsPair('Accept', 'application/vnd.github+json'),
        reason: 'GitHub REST API requires the preview accept header',
      );
    });

    test('checkLatest_truncatesNotesTo200Characters', () async {
      final longNotes = 'x' * 250;
      final client = FakeUpdateHttpClient.json(
        releaseJson(body: longNotes),
      );

      final release = await serviceWith(client).checkLatest();

      expect(release.notes.length, 200, reason: 'first 200 chars only');
      expect(release.notes, 'x' * 200);
    });

    test('checkLatest_keepsShortNotesUntouched', () async {
      final client = FakeUpdateHttpClient.json(
        releaseJson(body: 'short'),
      );

      final release = await serviceWith(client).checkLatest();

      expect(release.notes, 'short');
    });

    test('checkLatest_picksFirstApkAssetAmongOthers', () async {
      final client = FakeUpdateHttpClient.json(
        releaseJson(
          assets: '''
    {"name": "notes.txt",
     "browser_download_url": "https://example.com/notes.txt"},
    {"name": "app.apk",
     "browser_download_url": "https://example.com/app.apk"}''',
        ),
      );

      final release = await serviceWith(client).checkLatest();

      expect(release.apkUrl.toString(), 'https://example.com/app.apk');
    });

    test('checkLatest_toleratesMissingNotesAndPublishDate', () async {
      final client = FakeUpdateHttpClient.json(
        '{"tag_name": "v0.1.1", "assets": ['
            ' {"name": "app.apk", '
            ' "browser_download_url": "https://e.com/app.apk"}]}',
      );

      final release = await serviceWith(client).checkLatest();

      expect(release.notes, '');
      expect(release.publishedAt, isNull);
    });
  });

  group('checkLatest error paths (typed, never silent)', () {
    test('checkLatest_maps404ToHttpStatus', () async {
      final client = FakeUpdateHttpClient.json('{"message": "Not Found"}',
        status: 404);

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>()
              .having((e) => e.reason, 'reason',
                  UpdateFailureReason.httpStatus)
              .having((e) => e.message, 'message', contains('404')),
        ),
      );
    });

    test('checkLatest_mapsMalformedJsonToBadResponse', () async {
      final client = FakeUpdateHttpClient.json('{not json');

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.badResponse,
          ),
        ),
      );
    });

    test('checkLatest_mapsNonObjectBodyToBadResponse', () async {
      final client = FakeUpdateHttpClient.json('[1, 2, 3]');

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.badResponse,
          ),
        ),
      );
    });

    test('checkLatest_mapsMissingTagToBadResponse', () async {
      final client = FakeUpdateHttpClient.json(
        '{"assets": [{"name": "a.apk", "browser_download_url": "u"}]}',
      );

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.badResponse,
          ),
        ),
      );
    });

    test('checkLatest_mapsEmptyTagToBadResponse', () async {
      final client = FakeUpdateHttpClient.json(
        '{"tag_name": "", "assets": []}',
      );

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.badResponse,
          ),
        ),
      );
    });

    test('checkLatest_mapsNoApkAssetToNoApkAsset', () async {
      final client = FakeUpdateHttpClient.json(
        releaseJson(
          assets:
              '{"name": "notes.txt", "browser_download_url": "u.txt"}',
        ),
      );

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.noApkAsset,
          ),
        ),
      );
    });

    test('checkLatest_mapsEmptyAssetListToNoApkAsset', () async {
      final client = FakeUpdateHttpClient.json(
        releaseJson(assets: ''),
      );

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.noApkAsset,
          ),
        ),
      );
    });

    test('checkLatest_mapsSocketExceptionToOffline', () async {
      final client = FakeUpdateHttpClient(
        (url, {headers}) async => throw const SocketException('down'),
      );

      await expectLater(
        serviceWith(client).checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.offline,
          ),
        ),
      );
    });

    test('checkLatest_mapsStalledRequestToTimeout', () async {
      final client = FakeUpdateHttpClient(
        (url, {headers}) => Completer<UpdateHttpResponse>().future,
      );
      final service = UpdateService(
        client: client,
        timeout: Duration.zero,
      );

      await expectLater(
        service.checkLatest(),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.timeout,
          ),
        ),
      );
    });
  });

  group('downloadApk', () {
    UpdateHttpResponse streamed({
      required List<List<int>> chunks,
      int? contentLength,
      int status = 200,
    }) => UpdateHttpResponse(
      status: status,
      contentLength: contentLength,
      body: Stream<List<int>>.fromIterable(chunks),
    );

    test('downloadApk_forwardsChunksToSinkInOrder', () async {
      final chunks = [
        [1, 2, 3],
        [4, 5],
        [6],
      ];
      final client = FakeUpdateHttpClient(
        (url, {headers}) async =>
            streamed(chunks: chunks, contentLength: 6),
      );
      final received = <int>[];

      await serviceWith(client).downloadApk(
        Uri.parse('https://example.com/app.apk'),
        sink: received.addAll,
      );

      expect(received, [1, 2, 3, 4, 5, 6]);
    });

    test('downloadApk_reportsCumulativeFractions', () async {
      final chunks = [
        List<int>.filled(10, 1),
        List<int>.filled(10, 1),
        List<int>.filled(10, 1),
      ];
      final client = FakeUpdateHttpClient(
        (url, {headers}) async =>
            streamed(chunks: chunks, contentLength: 30),
      );
      final fractions = <double>[];

      await serviceWith(client).downloadApk(
        Uri.parse('https://example.com/app.apk'),
        sink: (_) {},
        onProgress: fractions.add,
      );

      expect(fractions.length, 3, reason: 'one report per chunk');
      // Thirds are not exact in binary; epsilon = float rounding.
      expect(fractions[0], closeTo(1 / 3, 1e-9),
          reason: 'float rounding tolerance');
      expect(fractions[1], closeTo(2 / 3, 1e-9),
          reason: 'float rounding tolerance');
      expect(fractions[2], 1.0);
    });

    test('downloadApk_clampsFractionWhenBodyExceedsContentLength',
        () async {
      final chunks = [
        List<int>.filled(15, 1),
        List<int>.filled(10, 1),
      ];
      final client = FakeUpdateHttpClient(
        (url, {headers}) async =>
            streamed(chunks: chunks, contentLength: 20),
      );
      final fractions = <double>[];

      await serviceWith(client).downloadApk(
        Uri.parse('https://example.com/app.apk'),
        sink: (_) {},
        onProgress: fractions.add,
      );

      expect(fractions.last, 1.0,
          reason: 'lying Content-Length must clamp, not exceed');
      expect(fractions.first, closeTo(0.75, 1e-9));
    });

    test('downloadApk_skipsProgressWhenSizeUnknown', () async {
      final client = FakeUpdateHttpClient(
        (url, {headers}) async =>
            streamed(chunks: [List<int>.filled(5, 1)]),
      );
      final fractions = <double>[];

      await serviceWith(client).downloadApk(
        Uri.parse('https://example.com/app.apk'),
        sink: (_) {},
        onProgress: fractions.add,
      );

      expect(fractions, isEmpty,
          reason: 'no total known — no fraction to report');
    });

    test('downloadApk_maps404ToHttpStatus', () async {
      final client = FakeUpdateHttpClient(
        (url, {headers}) async => streamed(
          chunks: [utf8.encode('gone')],
          contentLength: 4,
          status: 404,
        ),
      );

      await expectLater(
        serviceWith(client).downloadApk(
          Uri.parse('https://example.com/app.apk'),
          sink: (_) {},
        ),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.httpStatus,
          ),
        ),
      );
    });

    test('downloadApk_mapsMidStreamSocketDropToOffline', () async {
      final client = FakeUpdateHttpClient(
        (url, {headers}) async => UpdateHttpResponse(
          status: 200,
          contentLength: 100,
          body: Stream<List<int>>.error(const SocketException('reset')),
        ),
      );

      await expectLater(
        serviceWith(client).downloadApk(
          Uri.parse('https://example.com/app.apk'),
          sink: (_) {},
        ),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.reason,
            'reason',
            UpdateFailureReason.offline,
          ),
        ),
      );
    });
  });

  group('install', () {
    test('install_invokesChannelWithAbsolutePath', () async {
      String? sentPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        UpdateService.installMethodChannel,
        (call) async {
          sentPath = (call.arguments as Map)['path'] as String;
          return true;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              UpdateService.installMethodChannel,
              null,
            ),
      );

      await UpdateService().install('/cache/updates/app.apk');

      expect(sentPath, '/cache/updates/app.apk');
    });

    test('install_mapsPlatformErrorToInstallFailed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        UpdateService.installMethodChannel,
        (call) async =>
            throw PlatformException(code: 'noActivity', message: 'bad'),
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              UpdateService.installMethodChannel,
              null,
            ),
      );

      await expectLater(
        UpdateService().install('/cache/updates/app.apk'),
        throwsA(
          isA<UpdateException>()
              .having((e) => e.reason, 'reason',
                  UpdateFailureReason.installFailed)
              .having(
                (e) => e.message,
                'message',
                contains('noActivity'),
              ),
        ),
      );
    });
  });
}
