import 'dart:async' show Completer;

import 'package:app/app_config.dart';
import 'package:app/design/tokens.dart';
import 'package:app/presentation/settings_update_row.dart';
import 'package:app/update/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [UpdateService] stand-in: scripted outcomes + call recording
/// (no network, docs/03 § 10.2.9).
final class ScriptedUpdateService extends UpdateService {
  ScriptedUpdateService()
    : super(client: _UnusedHttpClient());

  /// Completer feeding the next `checkLatest` (null: offline plan).
  Completer<ReleaseInfo>? checkPlan;

  /// Completer feeding the next `install` (null: instant success).
  Completer<void>? installPlan;

  int checkCalls = 0;
  int installCalls = 0;
  final List<String> installedPaths = [];

  @override
  Future<ReleaseInfo> checkLatest() {
    checkCalls++;
    final plan = checkPlan;
    if (plan == null) {
      return Future<ReleaseInfo>.error(
        const UpdateException(
          UpdateFailureReason.offline,
          'scripted: no plan armed',
        ),
      );
    }
    return plan.future;
  }

  @override
  Future<void> install(String path) {
    installCalls++;
    installedPaths.add(path);
    final plan = installPlan;
    if (plan == null) {
      return Future<void>.value();
    }
    return plan.future;
  }
}

final class _UnusedHttpClient implements UpdateHttpClient {
  @override
  Future<UpdateHttpResponse> fetch(
    Uri url, {
    Map<String, String>? headers,
  }) => Future<UpdateHttpResponse>.error(
    StateError('scripted service never fetches'),
  );
}

ReleaseInfo _release(String tag) => ReleaseInfo(
  tag: tag,
  notes: 'Shiny release notes.',
  apkUrl: Uri.parse('https://example.com/app.apk'),
  publishedAt: DateTime.parse('2026-09-01T10:00:00Z'),
);

void main() {
  late ScriptedUpdateService service;

  Future<void> pumpRow(
    WidgetTester tester, {
    ApkDownloadDriver? driver,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SettingsUpdateRow(service: service, downloadDriver: driver),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => service = ScriptedUpdateService());

  testWidgets('entry starts checking with an inline spinner', (
    tester,
  ) async {
    service.checkPlan = Completer<ReleaseInfo>();

    await pumpRow(tester);

    expect(find.byType(SettingsUpdateRow), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('UP TO DATE'), findsNothing);
  });

  testWidgets('latest equal to current shows UP TO DATE tinted success', (
    tester,
  ) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;

    await pumpRow(tester);
    check.complete(_release('v$appVersion'));
    await tester.pump();

    final verdict = tester.widget<Text>(find.text('UP TO DATE'));
    expect(
      verdict.style?.color,
      ColorPalette.success,
      reason: 'up-to-date verdict carries the success tint (guide § 3)',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('older latest than current still shows UP TO DATE', (
    tester,
  ) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;

    await pumpRow(tester);
    check.complete(_release('v0.0.1'));
    await tester.pump();

    expect(find.text('UP TO DATE'), findsOneWidget);
  });

  testWidgets('newer release shows NEW VERSION with tag, notes and action', (
    tester,
  ) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;

    await pumpRow(tester);
    check.complete(_release('v9.9.9'));
    await tester.pump();

    expect(
      find.textContaining('NEW VERSION v9.9.9'),
      findsOneWidget,
      reason: 'anchor per docs/03 § 9 update-row states',
    );
    expect(find.textContaining('Shiny release notes.'), findsOneWidget);
    expect(find.text('DOWNLOAD UPDATE'), findsOneWidget);
  });

  testWidgets('failed check shows retry action and tapping re-checks', (
    tester,
  ) async {
    final first = Completer<ReleaseInfo>();
    service.checkPlan = first;
    final second = Completer<ReleaseInfo>();

    await pumpRow(tester);
    first.completeError(
      const UpdateException(
        UpdateFailureReason.offline,
        'scripted offline',
      ),
    );
    await tester.pump();

    expect(find.text('CHECK FOR UPDATES'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    service.checkPlan = second;
    await tester.tap(find.text('CHECK FOR UPDATES'));
    await tester.pump();

    expect(service.checkCalls, 2, reason: 'retry must re-run the check');
    second.complete(_release('v$appVersion'));
    await tester.pump();
    expect(find.text('UP TO DATE'), findsOneWidget);
  });

  testWidgets('download tap reveals the progress row and fills it', (
    tester,
  ) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;
    final download = Completer<String>();
    void Function(double)? reportedProgress;
    Future<String> driver(
      Uri url, {
      void Function(double fraction)? onProgress,
    }) {
      reportedProgress = onProgress;
      return download.future;
    }

    await pumpRow(tester, driver: driver);
    check.complete(_release('v9.9.9'));
    await tester.pump();
    await tester.tap(find.text('DOWNLOAD UPDATE'));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(SettingsUpdateRow.progressBarKey),
    );
    expect(bar.value, 0, reason: 'progress starts empty');

    reportedProgress?.call(0.4);
    await tester.pump();

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(SettingsUpdateRow.progressBarKey),
          )
          .value,
      0.4,
      reason: 'progress reflects the cumulative download fraction',
    );
    expect(find.text('DOWNLOAD UPDATE'), findsNothing,
        reason: 'action hidden while downloading');
    download.complete('/cache/updates/app.apk');
    await tester.pump();
  });

  testWidgets('completed download installs via the service', (tester) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;

    await pumpRow(
      tester,
      driver: (url, {onProgress}) =>
          Future<String>.value('/cache/updates/app.apk'),
    );
    check.complete(_release('v9.9.9'));
    await tester.pump();

    await tester.tap(find.text('DOWNLOAD UPDATE'));
    await tester.pump();

    expect(service.installedPaths, ['/cache/updates/app.apk']);
  });

  testWidgets('install failure lands on the error row', (tester) async {
    final check = Completer<ReleaseInfo>();
    service.checkPlan = check;
    final install = Completer<void>();
    service.installPlan = install;

    await pumpRow(
      tester,
      driver: (url, {onProgress}) =>
          Future<String>.value('/cache/updates/app.apk'),
    );
    check.complete(_release('v9.9.9'));
    await tester.pump();
    await tester.tap(find.text('DOWNLOAD UPDATE'));
    await tester.pump();

    install.completeError(
      const UpdateException(
        UpdateFailureReason.installFailed,
        'scripted install failure',
      ),
    );
    await tester.pump();

    expect(find.text('CHECK FOR UPDATES'), findsOneWidget,
        reason: 'failed install must not dead-end (ux-checklist row)');
  });
}
