import 'package:app/game/course/course_map.dart';
import 'package:app/game/view/race_game_view.dart';
import 'package:app/net/remote/render_feed.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Scripted feed: always returns the same two-player state.
final class _ScriptedFeed implements RenderFeed {
  _ScriptedFeed(this.map);

  @override
  final CourseMap map;

  @override
  final PlayerId localPlayerId = 'p1';

  int sampled = 0;

  @override
  RemoteRenderState sample() {
    sampled++;
    return RemoteRenderState(
      localPlayerId: localPlayerId,
      worldTick: 120,
      players: const {
        'p1': PlayerRenderPose(x: 5, y: 1, angle: 0),
        'p2': PlayerRenderPose(x: 8, y: 1, angle: 0),
      },
    );
  }
}

void main() {
  testWidgets('remote view renders without stepping any simulation', (
    tester,
  ) async {
    final map = CourseMap.trapRace(7);
    final feed = _ScriptedFeed(map);
    final game = RaceGameView(localPlayerId: 'p1', map: map, renderFeed: feed);

    // A manual update call must not accumulate into simulation steps;
    // the GameWidget pumps below must not either.
    expect((game..update(0.032)).stepCount, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(game.stepCount, 0);
    // The render path pulled from the feed, not from a simulation.
    expect(feed.sampled, greaterThan(0));
    game.onRemove();
  });

  test('remote view exposes no simulation and no events', () {
    final map = CourseMap.trapRace(7);
    final game = RaceGameView(
      localPlayerId: 'p1',
      map: map,
      renderFeed: _ScriptedFeed(map),
    );
    expect(game.simulation, isNull);
    expect(game.finished, isFalse);
    game.onRemove();
  });
}
