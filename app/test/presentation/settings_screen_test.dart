import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/credits_screen.dart';
import 'package:app/presentation/settings_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  late FakeKeyValueStorage storage;
  late ProfileController controller;

  Future<void> pumpScreen(WidgetTester tester) async {
    controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsScreen(controller: controller)),
      ),
    );
    await tester.pump();
  }

  setUp(() => storage = FakeKeyValueStorage());

  testWidgets('sound toggle starts on, flips off and persists', (tester) async {
    await pumpScreen(tester);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(SettingsScreen.soundToggleKey),
    );
    expect(toggle.value, isTrue);

    await tester.tap(find.byKey(SettingsScreen.soundToggleKey));
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<SwitchListTile>(find.byKey(SettingsScreen.soundToggleKey))
          .value,
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
    expect(find.byKey(CreditsScreen.fredokaRowKey), findsOneWidget);
    expect(find.byKey(CreditsScreen.nunitoRowKey), findsOneWidget);
  });

  testWidgets('version footer shows the app version const', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('0.1.0'), findsOneWidget);
  });
}
