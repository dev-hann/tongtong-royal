import 'package:test/test.dart';
import 'package:tongtong_shared/src/domain/domain.dart';

final class _FakeRace implements MiniGame {
  @override
  MiniGameId get id => 'fake_race';

  @override
  MiniGameSpec get spec => const MiniGameSpec(
    name: 'Fake Race',
    oneLineRule: 'First to the line wins.',
    timeoutMs: 90_000,
  );

  @override
  RoundResult resolve(RoundEvents events) => RoundResult(
    roundIndex: events.roundIndex,
    minigameId: id,
    placements: Placements.fromRankGroups(
      [
        for (final player in events.players)
          [player],
      ],
      events.players.length,
    ),
  );
}

void main() {
  test('spec exposes name one_liner_and_timeout', () {
    final spec = _FakeRace().spec;

    expect(spec.name, 'Fake Race');
    expect(spec.oneLineRule, 'First to the line wins.');
    expect(spec.timeoutMs, 90_000);
  });

  test('id_identifies_the_minigame', () {
    expect(_FakeRace().id, 'fake_race');
  });

  test('resolve_returns_round_result_for_same_round_and_id', () {
    final game = _FakeRace();
    const events = RoundEvents(
      roundIndex: 2,
      events: [
        PlayerFinished(tick: 10, playerId: 'a'),
        PlayerFinished(tick: 20, playerId: 'b'),
      ],
    );

    final result = game.resolve(events);

    expect(result.roundIndex, 2);
    expect(result.minigameId, 'fake_race');
    expect(result.placements.first.playerId, 'a');
    expect(result.placements.first.rank, 1);
  });

  test('round_events_preserve_order_and_expose_players', () {
    const a = PlayerFinished(tick: 5, playerId: 'a');
    const b = PlayerFell(tick: 7, playerId: 'b');
    const c = PlayerEliminated(tick: 9, playerId: 'c');
    const d = HoldTimeSample(playerId: 'a', seconds: 3.5);

    const events = RoundEvents(
      roundIndex: 0,
      events: [a, b, c, d],
    );

    expect(events.events, [a, b, c, d]);
    expect(events.players, ['a', 'b', 'c']);
  });

  test('round_events_accepts_empty_event_list', () {
    const events = RoundEvents(roundIndex: 0);

    expect(events.events, isEmpty);
    expect(events.players, isEmpty);
  });

  test('event_types_are_sealed_hierarchy', () {
    const RoundEvent event = PlayerFinished(tick: 1, playerId: 'a');

    final described = switch (event) {
      PlayerFinished(:final tick, :final playerId) =>
        'finished:$tick:$playerId',
      PlayerFell(:final tick, :final playerId) => 'fell:$tick:$playerId',
      PlayerEliminated(:final tick, :final playerId) =>
        'eliminated:$tick:$playerId',
      HoldTimeSample(:final playerId, :final seconds) =>
        'held:$playerId:$seconds',
    };

    expect(described, 'finished:1:a');
  });

  test('hold_time_sample_carries_seconds_not_ticks', () {
    const sample = HoldTimeSample(playerId: 'a', seconds: 12.5);

    expect(sample.playerId, 'a');
    expect(sample.seconds, 12.5);
  });

  test('round_events_carry_quota_roster_and_final_flag', () {
    const events = RoundEvents(
      roundIndex: 1,
      events: [PlayerFinished(tick: 5, playerId: 'a')],
      quota: 3,
      isFinal: true,
      roster: {'a', 'b'},
    );

    expect(events.quota, 3);
    expect(events.isFinal, isTrue);
    expect(events.roster, {'a', 'b'});
  });

  test('round_events_v1_defaults_keep_legacy_callsites_valid', () {
    const events = RoundEvents(roundIndex: 0);

    expect(events.quota, isNull);
    expect(events.isFinal, isFalse);
    expect(events.roster, isEmpty);
    expect(events.events, isEmpty);
  });
}
