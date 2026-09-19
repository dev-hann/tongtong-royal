import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_back_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/profile_screen.dart';
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
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    // Two settle pumps: the card groups' staggered-entrance timers
    // fire on the first, the slide/fade needs a second frame.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() => storage = FakeKeyValueStorage());

  testWidgets('top-left back affordance pops the route', (tester) async {
    final profileController = ProfileController(
      store: ProfileStore(storage: storage),
    );
    await profileController.load();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator))
      ..push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(controller: profileController),
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

  testWidgets('shows avatar initial, nickname and zeroed stats', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('PLAYER'), findsWidgets);
    expect(find.byKey(ProfileScreen.avatarKey), findsOneWidget);
    expect(find.byKey(ProfileScreen.nicknameFieldKey), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('nickname edit persists through the storage on submit', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(ProfileScreen.nicknameFieldKey),
      ' HANN ',
    );
    // Let the field's counter decoration relayout before tapping.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ProfileScreen.saveNicknameButtonKey));
    await tester.pump();
    await tester.pump();

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.profile.nickname, 'HANN');
  });

  testWidgets('palette selection updates the avatar color and persists', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('profile_swatch_2')));
    await tester.pump();
    await tester.pump();

    final avatar = tester.widget<Container>(
      find.byKey(ProfileScreen.avatarKey),
    );
    expect(
      avatar.decoration,
      isA<BoxDecoration>().having((d) => d.color, 'color', PlayerPalette.three),
    );

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.profile.colorIndex, 2);
  });

  testWidgets('form law: fixed header over three card sections', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(TtrPageHeader), findsOneWidget);
    expect(find.byType(TtrCardGroup), findsNWidgets(3));
    expect(find.text('IDENTITY'), findsOneWidget);
    expect(find.text('COLOR'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
  });

  testWidgets('form law: SAVE stretches the identity card width', (
    tester,
  ) async {
    await pumpScreen(tester);

    final save = tester.getSize(
      find.byKey(ProfileScreen.saveNicknameButtonKey),
    );
    final body = tester.getSize(find.byType(SingleChildScrollView));
    expect(
      save.width,
      body.width - 2 * (SpacingScale.xl + SpacingScale.md + SpacingScale.xs),
      reason: 'body padding + card padding + card border on each side',
    );
  });

  testWidgets('form law: avatar renders at the tokenized component size', (
    tester,
  ) async {
    await pumpScreen(tester);

    final avatar = tester.getSize(find.byKey(ProfileScreen.avatarKey));
    expect(avatar, const Size(ComponentSizes.avatar, ComponentSizes.avatar));
  });

  testWidgets('too-long nickname shows an error and saves nothing', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(ProfileScreen.nicknameFieldKey),
      'A' * 13,
    );
    // Let the field's counter decoration relayout before tapping.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ProfileScreen.saveNicknameButtonKey));
    await tester.pump();

    expect(find.text('1-12 characters after trimming'), findsOneWidget);

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.profile.nickname, Profile.defaultNickname);
  });
}
