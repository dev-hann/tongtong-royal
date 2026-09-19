import 'package:app/infra/profile_store.dart';
import 'package:app/infra/sound_service.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_key_value_storage.dart';
import 'fake_sfx_player.dart';

void main() {
  late FakeSfxPlayer player;
  late ProfileController profile;

  SoundService buildService({void Function(String, Object)? onError}) =>
      SoundService(player: player, profile: profile, onError: onError);

  setUp(() async {
    player = FakeSfxPlayer();
    final store = ProfileStore(storage: FakeKeyValueStorage());
    await store.load();
    profile = ProfileController(store: store);
  });

  test('sound_service_plays_the_asset_of_each_sfx', () {
    buildService().play(Sfx.uiTap);

    expect(player.plays.single, ('sfx/ui_tap.ogg', 1.0));
  });

  test('sound_service_forwards_the_requested_volume', () {
    buildService().play(Sfx.fail, volume: 0.5);

    expect(player.plays.single.$2, 0.5);
  });

  test('sound_service_play_is_silent_while_muted', () async {
    final service = buildService();
    await profile.setSoundEnabled(value: false);

    service.play(Sfx.jump);

    expect(player.plays, isEmpty);
  });

  test('sound_service_unmute_restores_playback', () async {
    final service = buildService();
    await profile.setSoundEnabled(value: false);
    await profile.setSoundEnabled(value: true);

    service.play(Sfx.jump);

    expect(player.plays.single.$1, 'sfx/jump.ogg');
  });

  test('sound_service_muting_stops_active_players_instantly', () async {
    buildService();

    await profile.setSoundEnabled(value: false);

    expect(player.stopCalls, 1);
  });

  test('sound_service_player_errors_are_reported_not_swallowed', () async {
    player.playError = StateError('boom');
    final reported = <Object>[];
    buildService(
      onError: (message, error) => reported
        ..add(message)
        ..add(error),
    ).play(Sfx.fanfare);

    // The error surfaces through the play future's error path.
    await pumpEventQueue();

    expect(reported, hasLength(2));
    expect(reported.first, 'sfx playback failed: sfx/fanfare.ogg');
    expect(reported.last, isA<StateError>());
  });
}
