import 'dart:async';

import 'package:app/game/arenas/hill/hill_arena_builder.dart';
import 'package:app/game/arenas/hill/hill_arena_map.dart';
import 'package:app/game/character_world.dart';
import 'package:app/game/course/race_simulation.dart'
    show stuckDisplacementEpsilonMeters;
import 'package:app/game/player_character.dart';
import 'package:app/game/round_simulation.dart';
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Bottom-of-player settle tolerance for the crown occupancy test,
/// meters: solver penetration after landing stays well under this,
/// so a standing player never fails the top-surface height check.
/// Engineering bound, not gameplay tuning.
const double _crownSettleEpsilon = 0.05;

/// Per-player hill state. Thin wrapper: physics lives on
/// [PlayerCharacter], rules live nowhere (events only).
final class _HillPlayer {
  _HillPlayer(this.id, this.character, this.spawnPoint)
    : stuckReference = spawnPoint.clone();

  final PlayerId id;
  final PlayerCharacter character;

  /// Floor respawn anchor for this player slot.
  final Vector2 spawnPoint;

  /// Accumulated sole-occupancy hold time, seconds (GDD § 4.3).
  double holdSeconds = 0;
  bool moveInputActive = false;
  Vector2 stuckReference;
  double stuckElapsedSeconds = 0;
}

/// Round runner for a King of the Hill arena (GDD § 4.3): owns the
/// [CharacterWorld], the built arena and the players, advances the
/// simulation one fixed dt per tick and emits raw domain
/// [RoundEvent]s (hold-time samples, falls). Judging — ranking by
/// hold time — belongs to the domain resolver; the contested rule
/// (two or more occupants score nothing) is applied here because
/// only the simulation knows the occupancy (architecture doc § 2).
///
/// Occupancy detection choice: position test, not sensor contact. A
/// player occupies the crown zone iff grounded, its center within
/// [HillArenaMap.crownRadius] of the crown center horizontally, and
/// its box bottom at the platform's top surface (± settle epsilon).
/// Deterministic, and immune to floor-level players grazing a sensor
/// volume beside the platform.
final class HillSimulation implements RoundSimulation {
  /// Creates the simulation for [map], spawning every player at the
  /// map's floor spawn points, with the GDD timeout (75 s).
  HillSimulation({
    required HillArenaMap map,
    required Iterable<PlayerId> playerIds,
  }) : this.forTesting(
         map: map,
         playerIds: playerIds,
         stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
         timeoutTicks: defaultTimeoutTicks,
       );

  /// Same as the default constructor, with injectable stuck
  /// threshold and timeout (tests shrink them instead of waiting
  /// out 75 s of ticks).
  @visibleForTesting
  HillSimulation.forTesting({
    required this.map,
    required Iterable<PlayerId> playerIds,
    required this.stuckThresholdSeconds,
    required this.timeoutTicks,
  }) {
    HillArenaBuilder.build(_world, map);
    var slot = 0;
    for (final id in playerIds) {
      final spawn = map.spawnPoints[slot % map.spawnPoints.length];
      final player = _HillPlayer(
        id,
        _world.spawnPlayer(position: spawn),
        spawn,
      );
      _players[id] = player;
      slot++;
    }
  }

  /// The arena data driving this simulation.
  final HillArenaMap map;

  /// Stuck threshold in seconds for this simulation.
  final double stuckThresholdSeconds;

  /// Ticks after which the round is complete (timeout signal for
  /// the host state machine; no domain event).
  final int timeoutTicks;

  /// Timeout in ticks derived from the GDD § 4.3 75 s round
  /// timeout at the fixed tick rate.
  static int get defaultTimeoutTicks {
    const game = KingOfTheHill();
    return (game.spec.timeoutMs / 1000 * PhysicsConsts.tickRate).round();
  }

  final CharacterWorld _world = CharacterWorld();
  final Map<PlayerId, _HillPlayer> _players = {};
  final StreamController<RoundEvent> _eventSink =
      StreamController<RoundEvent>.broadcast(sync: true);

  int _tickCount = 0;
  bool _complete = false;

  /// Raw round events in emission order (synchronous broadcast:
  /// listeners observe each tick's events before the next one).
  @override
  Stream<RoundEvent> get events => _eventSink.stream;

  /// Current simulation tick (one per world step).
  int get currentTick => _tickCount;

  /// Whether the round timeout has been reached (complete signal).
  @override
  bool get isComplete => _complete;

  /// The underlying Forge2D body of [playerId] (renderers, tests).
  Body bodyOf(PlayerId playerId) => _player(playerId).character.body;

  /// Arena archetype: no course anchor, no progress sampling (hold
  /// time travels as HoldTimeSample events instead).
  @override
  double? get progressAnchorX => null;

  /// Snapshot pose of [playerId] (never eliminated mid-round).
  @override
  PlayerPose poseOf(PlayerId playerId) {
    final body = bodyOf(playerId);
    return (
      x: body.position.x,
      y: body.position.y,
      angle: body.angle,
      vx: body.linearVelocity.x,
      vy: body.linearVelocity.y,
    );
  }

  /// Accumulated hold time of [playerId], seconds (test surface).
  double holdSecondsOf(PlayerId playerId) => _player(playerId).holdSeconds;

  /// Releases the event stream.
  @override
  void dispose() => _eventSink.close();

  /// Applies [input] for [playerId] and advances the whole world one
  /// fixed dt (per-tick guards included, via [CharacterWorld.step]).
  void tick(PlayerId playerId, PlayerInputState input) {
    tickInputs({playerId: input});
  }

  /// Applies one input per player and advances the world a single
  /// fixed dt — the host's batched per-tick entry point. Players
  /// without an entry this tick idle (no input).
  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    for (final player in _players.values) {
      final input = inputs[player.id];
      if (input == null) {
        player.moveInputActive = false;
        continue;
      }
      player.moveInputActive = input.moveDir.length2 > 0;
      _applyInput(player.character, input);
    }
    _world.step();
    _tickCount++;
    _updateHoldTime();
    _postStepGuards();
    if (!_complete && _tickCount >= timeoutTicks) {
      _complete = true;
    }
  }

  static void _applyInput(PlayerCharacter character, PlayerInputState i) {
    character.applyMove(i.moveDir);
    if (i.jumpPressed) {
      character.jump();
    }
    if (i.dashPressed) {
      character.dash(i.moveDir);
    }
  }

  /// Sole occupant accumulates hold time at 1 s/s; two or more
  /// occupants accumulate nothing (contested, GDD § 4.3). Emits one
  /// [HoldTimeSample] per player every
  /// [PhysicsConsts.progressSampleIntervalTicks] ticks.
  void _updateHoldTime() {
    _HillPlayer? soleOccupant;
    var occupants = 0;
    for (final player in _players.values) {
      if (_isOnCrown(player)) {
        occupants++;
        soleOccupant = player;
      }
    }
    if (occupants == 1) {
      soleOccupant!.holdSeconds += PhysicsConsts.fixedDt;
    }

    if (_tickCount % PhysicsConsts.progressSampleIntervalTicks == 0) {
      for (final player in _players.values) {
        _eventSink.add(
          HoldTimeSample(playerId: player.id, seconds: player.holdSeconds),
        );
      }
    }
  }

  bool _isOnCrown(_HillPlayer player) {
    final body = player.character.body;
    if (!player.character.grounded) {
      return false;
    }
    final dx = (body.position.x - map.crownCenter.x).abs();
    if (dx > map.crownRadius) {
      return false;
    }
    final bottom = body.position.y - PlayerCharacter.heightMeters / 2;
    return bottom >= map.crownTopY - _crownSettleEpsilon;
  }

  void _postStepGuards() {
    for (final player in _players.values) {
      if (player.character.needsRespawn) {
        // Explosion guard (architecture doc § 5): silent recovery,
        // no domain event.
        _respawn(player);
        continue;
      }
      if (player.character.body.position.y < map.killY) {
        _eventSink.add(PlayerFell(tick: _tickCount, playerId: player.id));
        _respawn(player);
      }
      _updateStuck(player);
    }
  }

  void _updateStuck(_HillPlayer player) {
    final body = player.character.body;
    if (!player.moveInputActive) {
      player
        ..stuckReference = body.position.clone()
        ..stuckElapsedSeconds = 0;
      return;
    }
    final displacement = (body.position - player.stuckReference).length;
    if (displacement > stuckDisplacementEpsilonMeters) {
      player
        ..stuckReference = body.position.clone()
        ..stuckElapsedSeconds = 0;
      return;
    }
    player.stuckElapsedSeconds += PhysicsConsts.fixedDt;
    if (player.stuckElapsedSeconds >= stuckThresholdSeconds) {
      // Stuck respawn (architecture doc § 5): same mechanics as a
      // fall respawn, but not a fall — no PlayerFell event.
      _respawn(player);
    }
  }

  void _respawn(_HillPlayer player) {
    final point = player.spawnPoint;
    final character = player.character;
    player
      ..stuckReference = point.clone()
      ..stuckElapsedSeconds = 0;
    character
      ..needsRespawn = false
      ..grounded = false
      ..body.setTransform(point, 0)
      ..body.linearVelocity.setZero()
      ..body.angularVelocity = 0;
  }

  _HillPlayer _player(PlayerId playerId) {
    final player = _players[playerId];
    if (player == null) {
      throw ArgumentError.value(playerId, 'playerId', 'unknown player');
    }
    return player;
  }
}
