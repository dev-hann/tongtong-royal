import 'dart:async';

import 'package:app/game/round_simulation.dart';
import 'package:app/presentation/solo_standings.dart';
import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Minimal scripted [RoundSimulation]: each tick retires one player
/// (emitting both `PlayerFinished` for race judging and
/// `PlayerEliminated` for survival judging) and completes once every
/// roster player retired.
class _ScriptedRaceSim implements RoundSimulation {
  _ScriptedRaceSim({required this.roster});

  final List<PlayerId> roster;
  final StreamController<RoundEvent> _sink =
      StreamController<RoundEvent>.broadcast(sync: true);
  int _ticks = 0;

  @override
  Stream<RoundEvent> get events => _sink.stream;

  @override
  bool get isComplete => _ticks >= roster.length;

  @override
  double? get progressAnchorX => 0;

  @override
  PlayerPose? poseOf(PlayerId playerId) => (x: 0, y: 0, angle: 0, vx: 0, vy: 0);

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    final playerId = roster[_ticks % roster.length];
    _sink.add(PlayerFinished(tick: _ticks, playerId: playerId));
    _sink.add(PlayerEliminated(tick: _ticks, playerId: playerId));
    _ticks++;
  }

  @override
  void dispose() => _sink.close();
}

/// Manual clock: records scheduled callbacks; tests fire them by
/// elapsing virtual time.
class _ManualClock {
  final List<(Duration, VoidCallback)> pending = [];

  void schedule(Duration delay, VoidCallback callback) {
    pending.add((delay, callback));
  }

  /// Advances virtual time by [seconds], firing callbacks as their
  /// delays elapse (one-second granularity; freshly scheduled
  /// callbacks join the pending queue with their full delay).
  void elapseSeconds(int seconds) {
    for (var elapsed = 0; elapsed < seconds; elapsed++) {
      final due = [...pending];
      pending.clear();
      for (final (delay, callback) in due) {
        if (delay <= const Duration(seconds: 1)) {
          callback();
        } else {
          pending.add((delay - const Duration(seconds: 1), callback));
        }
      }
    }
  }
}

void main() {
  late ShellController shell;
  late SoloMatchController solo;
  late _ManualClock clock;

  setUp(() {
    shell = ShellController();
    clock = _ManualClock();
    solo = SoloMatchController(
      shell: shell,
      config: const SoloMatchConfig(
        humanId: 'you',
        rounds: 2,
        matchSeed: 7,
      ),
      simulationFactory: (id, seed, roster) => _ScriptedRaceSim(
        roster: roster.toList(),
      ),
      scheduler: clock.schedule,
    );
  });

  tearDown(() {
    solo.dispose();
    shell.dispose();
  });

  void playRound() {
    solo.startSolo(); // lobby -> intro
    clock.elapseSeconds(3); // intro countdown -> play
    final session = solo.currentRound!;
    while (!session.driver.isRoundOver) {
      session.driver.tick();
    }
    clock.elapseSeconds(6); // results dwell -> next phase
  }

  test('standings empty before any completed round', () {
    expect(solo.standings, isEmpty);
    expect(solo.standingsAfterLatestRound, isEmpty);
    expect(solo.remainingSeconds, isNull);
    expect(solo.resultsMinigameName, isNull);
  });

  test('standings reflect completed rounds via domain rankings', () {
    playRound();
    expect(shell.phase, RoundPhase.roundIntro); // advanced past results

    final standings = solo.standings;
    expect(standings, hasLength(4)); // human + 3 bot seats.
    final total = standings.fold<int>(0, (sum, e) => sum + e.points);
    expect(total, 10); // 4-player round: 4+3+2+1.
  });

  test('standingsAfterLatestRound exposes totals and round deltas', () {
    playRound();
    // Still in results dwell? playRound already advanced; rewind check:
    // deltas are only meaningful during results, so re-run to results.
    expect(shell.phase, RoundPhase.roundIntro);

    // Drive to the results phase of round 2 and inspect there.
    clock.elapseSeconds(3); // intro -> play
    final session = solo.currentRound!;
    while (!session.driver.isRoundOver) {
      session.driver.tick();
    }
    expect(shell.phase, RoundPhase.roundResults);

    final rows = solo.standingsAfterLatestRound;
    expect(rows, hasLength(4));
    final deltaSum = rows.fold<int>(0, (sum, e) => sum + e.roundDelta);
    expect(deltaSum, 10); // this round awarded 4+3+2+1.
    for (final row in rows) {
      expect(row.totalPoints, greaterThanOrEqualTo(row.roundDelta));
    }
    // Domain ordering: best total first.
    expect(
      rows.map((e) => e.totalPoints).toList(),
      isSortedDescending,
    );
  });

  test('remainingSeconds derives from the driver timeout budget', () {
    solo.startSolo();
    clock.elapseSeconds(3);
    final session = solo.currentRound!;
    final timeoutTicks = session.driver.timeoutTicks;

    final expected = ((timeoutTicks - session.driver.tickCount) *
            PhysicsConsts.fixedDt)
        .ceil();
    expect(solo.remainingSeconds, expected);

    // The scripted sim finishes after `roster.length` ticks; tick to
    // just before completion and confirm the value still tracks the
    // driver budget formula.
    for (var i = 0; i < 3; i++) {
      session.driver.tick();
    }
    final afterTicks = ((timeoutTicks - session.driver.tickCount) *
            PhysicsConsts.fixedDt)
        .ceil();
    expect(solo.remainingSeconds, afterTicks);
  });

  test('resultsMinigameName resolves the latest round display name', () {
    solo.startSolo();
    clock.elapseSeconds(3);
    final session = solo.currentRound!;
    while (!session.driver.isRoundOver) {
      session.driver.tick();
    }
    expect(shell.phase, RoundPhase.roundResults);
    expect(
      solo.resultsMinigameName,
      anyOf('Trap Race', 'Hammer Dodge'),
    );
  });
}

final isSortedDescending = predicate<List<int>>(
  (values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i - 1] < values[i]) {
        return false;
      }
    }
    return true;
  },
  'sorted descending',
);
