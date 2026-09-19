import 'package:app/infra/profile_store.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../infra/fake_key_value_storage.dart';

void main() {
  test('setNickname trims surrounding whitespace', () async {
    final controller = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await controller.load();

    final accepted = await controller.setNickname('  ACE  ');

    expect(accepted, isTrue);
    expect(controller.profile.nickname, 'ACE');
  });

  test('setNickname falls back to PLAYER for empty/whitespace input', () async {
    final controller = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await controller.load();

    expect(await controller.setNickname(''), isTrue);
    expect(controller.profile.nickname, Profile.defaultNickname);

    expect(await controller.setNickname('   '), isTrue);
    expect(controller.profile.nickname, Profile.defaultNickname);
  });

  test(
    'setNickname rejects input longer than 12 chars and keeps old value',
    () async {
      final controller = ProfileController(
        store: ProfileStore(storage: FakeKeyValueStorage()),
      );
      await controller.load();
      await controller.setNickname('ACE');

      final accepted = await controller.setNickname('A' * 13);

      expect(accepted, isFalse);
      expect(controller.profile.nickname, 'ACE');
    },
  );

  test('12 chars exactly is valid', () async {
    final controller = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await controller.load();

    expect(await controller.setNickname('A' * 12), isTrue);
    expect(controller.profile.nickname, 'A' * 12);
  });

  test('selectColor clamps out-of-range indices into the palette', () async {
    final controller = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await controller.load();

    controller.selectColor(7);
    expect(controller.profile.colorIndex, 3);

    controller.selectColor(-4);
    expect(controller.profile.colorIndex, 0);

    controller.selectColor(2);
    expect(controller.profile.colorIndex, 2);
  });

  test('nickname changes notify listeners and persist', () async {
    final storage = FakeKeyValueStorage();
    final controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setNickname('HANN');

    expect(notifications, 1);
    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.profile.nickname, 'HANN');
  });

  test('sound toggle flips and persists through the controller', () async {
    final storage = FakeKeyValueStorage();
    final controller = ProfileController(store: ProfileStore(storage: storage));
    await controller.load();

    expect(controller.soundEnabled, isTrue);
    await controller.setSoundEnabled(value: false);
    expect(controller.soundEnabled, isFalse);

    final reloaded = ProfileStore(storage: storage);
    await reloaded.load();
    expect(reloaded.settings.soundEnabled, isFalse);
  });

  test('completeOnboarding flips needsOnboarding once', () async {
    final controller = ProfileController(
      store: ProfileStore(storage: FakeKeyValueStorage()),
    );
    await controller.load();

    expect(controller.needsOnboarding, isTrue);
    await controller.completeOnboarding();
    expect(controller.needsOnboarding, isFalse);
  });
}
