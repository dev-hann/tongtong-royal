import 'package:app/app_config.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/design/widgets/ttr_settings_row.dart';
import 'package:app/design/widgets/ttr_switch.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/credits_screen.dart';
import 'package:app/presentation/settings_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:app/update/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

/// Up-to-date [UpdateService] fake for the surrounding-screen
/// tests (the row's own behaviors live in
/// `settings_update_row_test.dart`). No network (docs/03 § 10.2.9).
final class UpToDateUpdateService extends UpdateService {
  UpToDateUpdateService() : super(client: _UnusedHttpClient());

  int checkCalls = 0;

  @override
  Future<ReleaseInfo> checkLatest() async {
    checkCalls++;
    return ReleaseInfo(
      tag: 'v$appVersion',
      notes: 'current',
      apkUrl: Uri.parse('https://example.com/app.apk'),
    );
  }
}

final class _UnusedHttpClient implements UpdateHttpClient {
  @override
  Future<UpdateHttpResponse> fetch(
    Uri url, {
    Map<String, String>? headers,
  }) => Future<UpdateHttpResponse>.error(
    StateError('up-to-date service fake never fetches'),
  );
}

void main() {
  late FakeKeyValueStorage storage;
  late ProfileController controller;
  late UpToDateUpdateService updateService;

  Future<void> pumpScreen(WidgetTester tester) async {
    controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            updateService: updateService,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    storage = FakeKeyValueStorage();
    updateService = UpToDateUpdateService();
  });

  testWidgets('top-left back affordance pops the route', (tester) async {
    final profileController = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await profileController.load();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator))
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            controller: profileController,
            updateService: UpToDateUpdateService(),
          ),
        ),
      );
    await tester.pump();
    // Fixed pumps, not pumpAndSettle: the ambient backdrop animates
    // forever.
    await tester.pump(const Duration(milliseconds: 400));
    expect(navigator.canPop(), isTrue);

    await tester.tap(find.byKey(TtrBackButton.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(navigator.canPop(), isFalse);
  });

  testWidgets('sound toggle starts on, flips off and persists', (tester) async {
    await pumpScreen(tester);

    final toggle = tester.widget<TtrSwitch>(
      find.byKey(SettingsScreen.soundToggleKey),
    );
    expect(toggle.value, isTrue);

    await tester.tap(find.byKey(SettingsScreen.soundToggleKey));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TtrSwitch>(find.byKey(SettingsScreen.soundToggleKey)).value,
      isFalse,
    );

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.settings.soundEnabled, isFalse);
  });

  testWidgets('credits row pushes the credits screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(SettingsScreen.creditsRowKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CreditsScreen), findsOneWidget);
    expect(find.byKey(const Key('credits_row_Fredoka font')), findsOneWidget);
    expect(
      find.byKey(const Key('credits_row_Phosphor Icons (Fill)')),
      findsOneWidget,
    );
  });

  testWidgets('version footer shows the app version const', (tester) async {
    await pumpScreen(tester);

    expect(find.text('v$appVersion'), findsOneWidget);
  });

  testWidgets('form law: fixed header over three card sections', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(TtrPageHeader), findsOneWidget);
    expect(find.byType(TtrCardGroup), findsNWidgets(3));
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('UPDATE'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets(
    'rows use the design system with Phosphor icons (guide § 2.1, § 5)',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byType(TtrSettingsRow), findsNWidgets(3));
      expect(find.byIcon(TtrIcons.speakerHigh), findsOneWidget);
      expect(find.byIcon(TtrIcons.bookOpen), findsOneWidget);
      expect(find.byIcon(TtrIcons.downloadSimple), findsOneWidget);
      expect(find.byIcon(TtrIcons.caretRight), findsOneWidget);
    },
  );

  testWidgets('settings entry triggers the auto update check once', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(updateService.checkCalls, 1,
        reason: 'entry auto-query fires exactly once (ux-checklist row)');
  });

  testWidgets('auto check settles on the UP TO DATE row', (tester) async {
    await pumpScreen(tester);
    await tester.pump();

    expect(find.byKey(SettingsScreen.updateRowKey), findsOneWidget);
    expect(find.text('UP TO DATE'), findsOneWidget);
  });
}
