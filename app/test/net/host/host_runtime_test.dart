import 'package:app/infra/net_client.dart';
import 'package:app/net/host/host_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

import '../../infra/fake_connection.dart';
import 'host_harness.dart';

void main() {
  group('HostRuntime.startRound', () {
    test('emits RoundStarting with round, minigame, seed and spec timeout',
        () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();

      h.runtime.startRound(3, 'trap_race', 42);

      final starting = h.sentMessages.whereType<RoundStarting>().single;
      expect(starting.roundIndex, 3);
      expect(starting.minigameId, 'trap_race');
      expect(starting.mapSeed, 42);
      expect(starting.timeoutMs, const TrapRace().spec.timeoutMs);
      expect(h.runtime.isRoundActive, isTrue);
    });

    test('rejects starting while a round is running', () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();

      h.runtime.startRound(0, 'trap_race', 1);

      expect(() => h.runtime.startRound(1, 'trap_race', 2), throwsStateError);
    });
  });

  group('HostRuntime inputs', () {
    test('scripted input drives the player through snapshots', () async {
      final h = HostHarness(
        mapBuilder: (seed) => flatCourse(seed, finishX: 1000),
      );
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      h.driveRight(playerId: p1, ticks: 90);

      final snapshots = h.snapshotsSent;
      expect(snapshots, isNotEmpty);
      final first = snapshots.first.players.single;
      final last = snapshots.last.players.single;
      expect(last.x, greaterThan(first.x + 0.5));
      expect(h.runtime.isRoundActive, isTrue);
    });

    test('later seq wins when two samples arrive before a tick', () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      h.runtime.submitMemberInput(p1, inputSample(seq: 1, moveX: 1));
      h.runtime.submitMemberInput(p1, inputSample(seq: 2, moveX: -1));
      for (var i = 0; i < 60; i++) {
        h.tick();
      }

      final x = h.snapshotsSent.last.players.single.x;
      expect(x, lessThan(-0.5), reason: 'newer sample (left) must win');

      // Stale seq is dropped: the player keeps running left.
      h.runtime.submitMemberInput(p1, inputSample(seq: 1, moveX: 1));
      final before = h.snapshotsSent.last.players.single.x;
      for (var i = 0; i < 30; i++) {
        h.tick();
      }
      final after = h.snapshotsSent.last.players.single.x;
      expect(after, lessThanOrEqualTo(before));
    });

    test('absent player idles: zero input, body stays put (network doc 5.2)',
        () async {
      final h = HostHarness(roster: const {p1, p2});
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      // Settle spawn overlap, then compare positions across windows.
      for (var i = 0; i < 240; i++) {
        h.tick();
      }
      final snapshots = h.snapshotsSent;
      PlayerState stateOf(int tick) => snapshots
          .firstWhere((s) => s.tick == tick)
          .players
          .firstWhere((p) => p.playerId == p2);

      final settled = stateOf(120);
      final later = stateOf(240);
      expect(later.x, closeTo(settled.x, 0.05));
      expect(later.y, closeTo(settled.y, 0.05));
      expect(h.runtime.isRoundActive, isTrue);
      expect(snapshots.last.players, hasLength(2));
    });
  });

  group('HostRuntime snapshot cadence', () {
    test('60 fixed ticks produce exactly 20 snapshots with rising ticks',
        () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      for (var i = 0; i < 60; i++) {
        h.tick();
      }

      final ticks = h.snapshotsSent.map((s) => s.tick).toList();
      const expected = [
        3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48,
        51, 54, 57, 60,
      ];
      expect(ticks, hasLength(20));
      expect(ticks, expected);
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i], greaterThan(ticks[i - 1]));
      }
    });

    test('accumulator slices partial frames into whole ticks', () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      // 120 Hz frames: two frames per simulation tick, no drift.
      const dt = PhysicsConsts.fixedDt / 2;
      for (var i = 0; i < 120; i++) {
        h.runtime.advance(dt);
      }

      expect(h.runtime.currentTick, 60);
      expect(h.snapshotsSent, hasLength(20));
    });
  });

  group('HostRuntime round completion', () {
    test('all finished: results sent and onRoundComplete fires', () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();
      final completed = <RoundResult>[];
      h.runtime.onRoundComplete.listen(completed.add);

      h.runtime.startRound(0, 'trap_race', 7);
      h.driveRight(playerId: p1, ticks: 600);

      expect(h.runtime.isRoundActive, isFalse);
      final message = h.sentMessages.whereType<RoundResultsMessage>().single;
      final result = message.roundResult;
      expect(result.roundIndex, 0);
      expect(result.minigameId, 'trap_race');
      expect(result.placements.single.playerId, p1);
      expect(result.placements.single.rank, 1);
      expect(completed.single.roundIndex, result.roundIndex);
      expect(completed.single.placements, result.placements);

      // Round over: advancing is a no-op, no further traffic.
      final sentBefore = h.fake.sent.length;
      for (var i = 0; i < 30; i++) {
        h.tick();
      }
      expect(h.fake.sent.length, sentBefore);
    });

    test('timeout: progress-ranked placements via domain samples (GDD 7.4)',
        () async {
      final h = HostHarness(
        roster: const {p1, p2},
        mapBuilder: (seed) => flatCourse(seed, finishX: 1000),
      );
      addTearDown(h.client.dispose);
      await h.boot();
      final completed = <RoundResult>[];
      h.runtime.onRoundComplete.listen(completed.add);

      h.runtime.startRound(0, 'trap_race', 7);
      h.driveRight(playerId: p1, ticks: 60);
      expect(h.runtime.isRoundActive, isTrue, reason: 'finish unreachable');

      h.runtime.advance(90); // spec timeout: 90 s at 60 Hz
      expect(h.runtime.isRoundActive, isFalse);

      final result =
          h.sentMessages.whereType<RoundResultsMessage>().single.roundResult;
      expect(result.placements.first.playerId, p1);
      expect(result.placements.last.playerId, p2);
      expect(result.placements.first.rank, 1);
      expect(result.placements.last.rank, 2);
      expect(completed.single.roundIndex, result.roundIndex);
      expect(completed.single.placements, result.placements);
    });
  });

  group('HostRuntime guards', () {
    test('empty roster is rejected', () {
      expect(
        () => HostRuntime(
          client: _disposedClient(),
          game: const TrapRace(),
          roster: const {},
        ),
        throwsArgumentError,
      );
    });

    test('advance rejects negative and non-finite dt', () async {
      final h = HostHarness();
      addTearDown(h.client.dispose);
      await h.boot();
      h.runtime.startRound(0, 'trap_race', 7);

      expect(() => h.runtime.advance(-1), throwsArgumentError);
      expect(() => h.runtime.advance(double.nan), throwsArgumentError);
      expect(
        () => h.runtime.advance(double.infinity),
        throwsArgumentError,
      );
    });

    test('round timeout ticks derive from the minigame spec', () {
      final h = HostHarness();
      addTearDown(h.client.dispose);

      expect(h.runtime.roundTimeoutTicks, 90 * PhysicsConsts.tickRate);
    });
  });
}

NetClient _disposedClient() {
  final client = NetClient(
    connectionFactory: (_) async => FakeConnection(),
    clock: () => Duration.zero,
    backoff: (_) async {},
  );
  return client;
}
