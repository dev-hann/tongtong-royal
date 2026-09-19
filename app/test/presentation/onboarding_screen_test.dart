import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/onboarding_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  late FakeKeyValueStorage storage;
  late ProfileController controller;

  Future<void> pumpScreen(WidgetTester tester, VoidCallback onStart) async {
    controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingScreen(controller: controller, onStart: onStart),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() => storage = FakeKeyValueStorage());

  testWidgets('first launch shows nickname field, palette and START', (
    tester,
  ) async {
    await pumpScreen(tester, () {});

    expect(controller.needsOnboarding, isTrue);
    expect(find.byKey(OnboardingScreen.nicknameFieldKey), findsOneWidget);
    expect(find.byKey(OnboardingScreen.startButtonKey), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_swatch_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_swatch_3')), findsOneWidget);
  });

  testWidgets('START saves nickname + color and flips the onboarding flag', (
    tester,
  ) async {
    var started = false;
    await pumpScreen(tester, () => started = true);

    await tester.enterText(
      find.byKey(OnboardingScreen.nicknameFieldKey),
      'HANN',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding_swatch_2')));
    await tester.pump();
    await tester.tap(find.byKey(OnboardingScreen.startButtonKey));
    await tester.pump();
    await tester.pump();

    expect(started, isTrue);

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.onboarded, isTrue);
    expect(reloaded.profile.nickname, 'HANN');
    expect(reloaded.profile.colorIndex, 2);
  });

  testWidgets('empty nickname falls back to PLAYER on START', (tester) async {
    await pumpScreen(tester, () {});

    await tester.tap(find.byKey(OnboardingScreen.startButtonKey));
    await tester.pump();
    await tester.pump();

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.onboarded, isTrue);
    expect(reloaded.profile.nickname, Profile.defaultNickname);
  });
}
