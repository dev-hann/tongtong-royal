import 'package:app/design/tokens.dart';
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
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() => storage = FakeKeyValueStorage());

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

  testWidgets('too-long nickname shows an error and saves nothing', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(ProfileScreen.nicknameFieldKey),
      'A' * 13,
    );
    await tester.tap(find.byKey(ProfileScreen.saveNicknameButtonKey));
    await tester.pump();

    expect(find.text('1-12 characters after trimming'), findsOneWidget);

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.profile.nickname, Profile.defaultNickname);
  });
}
