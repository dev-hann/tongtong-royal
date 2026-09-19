import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/onboarding_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  late FakeKeyValueStorage storage;
  late ProfileController controller;

  Future<void> pumpScreen(
    WidgetTester tester,
    VoidCallback onStart, {
    VoidCallback? onSkip,
  }) async {
    controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingScreen(
            controller: controller,
            onStart: onStart,
            onSkip: onSkip ?? onStart,
          ),
        ),
      ),
    );
    // Two settle pumps: the card groups' staggered-entrance timers
    // fire on the first, the slide/fade needs a second frame.
    await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('form law: backless header carries SKIP, two card sections', (
    tester,
  ) async {
    await pumpScreen(tester, () {});

    expect(find.byType(TtrPageHeader), findsOneWidget);
    expect(find.byKey(TtrBackButton.buttonKey), findsNothing);
    expect(find.byKey(OnboardingScreen.skipButtonKey), findsOneWidget);
    expect(find.byType(TtrCardGroup), findsNWidgets(2));
    expect(find.text('IDENTITY'), findsOneWidget);
    expect(find.text('COLOR'), findsOneWidget);
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
    // Let the field's counter decoration relayout before tapping.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('SKIP completes onboarding storing the default profile', (
    tester,
  ) async {
    var skipped = false;
    await pumpScreen(tester, () {}, onSkip: () => skipped = true);

    // Typed-but-abandoned input must not persist through SKIP.
    await tester.enterText(
      find.byKey(OnboardingScreen.nicknameFieldKey),
      'TYPED',
    );
    await tester.tap(find.byKey(OnboardingScreen.skipButtonKey));
    await tester.pump();
    await tester.pump();

    expect(skipped, isTrue);
    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.onboarded, isTrue);
    expect(reloaded.profile.nickname, Profile.defaultNickname);
    expect(reloaded.profile.colorIndex, 0);
  });
}
