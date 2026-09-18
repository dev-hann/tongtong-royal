import 'dart:async';

import 'package:app/game/course/course_map.dart';
import 'package:app/game/view/race_game_view.dart' show InputSource;
import 'package:app/net/remote/remote_render_feed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

final class _StaticInput implements InputSource {
  _StaticInput(this.state);

  final PlayerInputState state;

  @override
  PlayerInputState sample() => state;
}

PlayerState _state(String id, double x) =>
    PlayerState(playerId: id, x: x, y: 0, angle: 0, vx: 0, vy: 0);

Snapshot _snap(int tick, List<PlayerState> players) =>
    Snapshot(tick: tick, players: players);

void main() {
  late StreamController<Snapshot> controller;
  late CourseMap map;
  var nowMs = 0;

  RemoteRenderFeed buildFeed({InputSource? input}) => RemoteRenderFeed(
    snapshots: controller.stream,
    localPlayerId: 'me',
    map: map,
    clock: () => Duration(milliseconds: nowMs),
    inputSource: input,
  );

  setUp(() {
    controller = StreamController<Snapshot>.broadcast();
    map = CourseMap.trapRace(7);
    nowMs = 0;
  });

  tearDown(() async => controller.close());

  test(
    'remote players interpolate between buffer entries, never predict',
    () async {
      final feed = buildFeed();
      addTearDown(feed.dispose);

      controller.add(_snap(1, [_state('me', 0), _state('r', 0)]));
      nowMs = 100;
      // Let the broadcast stream deliver.
      await Future<void>.delayed(Duration.zero);
      controller.add(_snap(2, [_state('me', 10), _state('r', 10)]));
      nowMs = 200;
      await Future<void>.delayed(Duration.zero);

      // Render clock midway between arrivals: remote lerps to 5.
      nowMs = 250;
      final state = feed.sample();
      expect(state.players['r']!.x, moreOrLessEquals(5, epsilon: 1e-9));
      // Remote pose stays within the buffered range [0, 10].
      expect(state.players['r']!.x, inInclusiveRange(0, 10));
      feed.dispose();
    },
  );

  test(
    'local player renders prediction seeded by authoritative state',
    () async {
      final feed = buildFeed(
        input: _StaticInput(PlayerInputState(moveDir: Vector2(1, 0))),
      );
      addTearDown(feed.dispose);

      controller.add(_snap(1, [_state('me', 0)]));
      nowMs = 100;
      await Future<void>.delayed(Duration.zero);

      // Sample twice: first sample integrates prediction forward from the
      // authoritative pose using the input; the interpolated buffer pose
      // for 'me' would be exactly 0.
      nowMs = 200;
      feed.sample();
      nowMs = 300;
      final state = feed.sample();
      // Predicted: 0 + (0 + 6) * 0.2 s (dt since previous sample) = 1.2,
      // then the next snapshot-integrated sample keeps integrating.
      expect(state.players['me']!.x, greaterThan(0));
      expect(state.localPlayerId, 'me');
      feed.dispose();
    },
  );

  test(
    'starved buffer holds remote players, own prediction continues',
    () async {
      final feed = buildFeed(
        input: _StaticInput(PlayerInputState(moveDir: Vector2(1, 0))),
      );
      addTearDown(feed.dispose);

      controller.add(_snap(1, [_state('me', 0), _state('r', 0)]));
      nowMs = 100;
      await Future<void>.delayed(Duration.zero);
      controller.add(_snap(2, [_state('me', 4), _state('r', 4)]));
      nowMs = 200;
      await Future<void>.delayed(Duration.zero);

      nowMs = 300;
      feed.sample(); // Establish the sample cadence.
      // Long silence: remote holds the newest buffered pose (4)...
      nowMs = 5000;
      final state = feed.sample();
      expect(state.players['r']!.x, 4);
      // ...while the local player keeps integrating input.
      expect(state.players['me']!.x, greaterThan(4));
      feed.dispose();
    },
  );

  test('no snapshots yet samples to an empty idle state', () async {
    final feed = buildFeed();
    addTearDown(feed.dispose);

    final state = feed.sample();
    expect(state.players, isEmpty);
    expect(state.worldTick, 0);
    feed.dispose();
  });
}
