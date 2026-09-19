import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_settings_row.dart';
import 'package:app/design/widgets/ttr_switch.dart';
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
    expect(find.byKey(CreditsScreen.fredokaRowKey), findsOneWidget);
    expect(find.byKey(CreditsScreen.nunitoRowKey), findsOneWidget);
  });

  testWidgets('version footer shows the app version const', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('0.1.0'), findsOneWidget);
  });

  testWidgets(
    'rows use the design system with Phosphor icons (guide § 2.1, § 5)',
    (tester) async {
      await pumpScreen(tester);

      expect(find.byType(TtrSettingsRow), findsNWidgets(2));
      expect(find.byIcon(TtrIcons.speakerHigh), findsOneWidget);
      expect(find.byIcon(TtrIcons.bookOpen), findsOneWidget);
      expect(find.byIcon(TtrIcons.caretRight), findsOneWidget);
    },
  );
}
