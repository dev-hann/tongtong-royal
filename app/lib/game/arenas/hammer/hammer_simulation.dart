import 'dart:async';

import 'package:app/game/arenas/hammer/hammer_builder.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/character_world.dart';
import 'package:app/game/player_character.dart';
import 'package:app/game/round_simulation.dart';
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Per-player arena state. Thin wrapper: physics lives on
/// [PlayerCharacter], rules live nowhere (events only).
final class _ArenaPlayer {
  _ArenaPlayer(this.id, this.character, this.spawnAnchor);

  final PlayerId id;
  final PlayerCharacter character;

  /// Spawn anchor for the silent explosion-recovery respawn.
  final Vector2 spawnAnchor;

  /// True until the player leaves the arena (fall, fling or mallet).
  bool alive = true;
}

/// Round runner for a Hammer Dodge arena (hammer-dodge.md): owns the
/// [CharacterWorld], the built arena and the players, advances the
/// simulation one fixed dt per tick, applies the shrink schedule and
/// emits raw domain [RoundEvent]s ([PlayerEliminated] only). Judging
/// — qualification from elimination order — belongs to the domain
/// resolver.
///
/// Elimination is final: the body is destroyed, there are no
/// checkpoints and no respawns into play (survival archetype). The
/// explosion guard still silently recovers a corrupted body back to
/// its spawn anchor (architecture doc § 5, no domain event).
///
/// Quota-aware completion (GDD § 7.1): the round ends the first
/// instant the alive count reaches the quota (or crosses below it —
/// same-tick multi-eliminations all emit and share qualification
/// domain-side); otherwise the GDD timeout completes it with every
/// survivor still standing.
final class HammerSimulation implements RoundSimulation {
  /// Creates the simulation for [map] with the GDD timeout (60 s).
  HammerSimulation({
    required HammerArenaMap map,
    required Iterable<PlayerId> playerIds,
    required int quota,
  }) : this.forTesting(
         map: map,
         playerIds: playerIds,
         quota: quota,
         timeoutTicks: defaultTimeoutTicks,
       );

  /// Same as the default constructor, with an injectable timeout
  /// (tests shrink it instead of waiting out 60 s of ticks).
  @visibleForTesting
  HammerSimulation.forTesting({
    required this.map,
    required Iterable<PlayerId> playerIds,
    required this.quota,
    required this.timeoutTicks,
  }) {
    if (quota < 1) {
      throw ArgumentError.value(quota, 'quota', 'must be at least 1');
    }
    _arena = HammerArenaBuilder(onPlayerEliminated: _onArenaHit).build(
      _world,
      map,
      resolvePlayer: (body) => _bodyToPlayer[body],
    );
    var slot = 0;
    for (final id in playerIds) {
      final spawn = map.spawnPoints[slot % map.spawnPoints.length];
      final player = _ArenaPlayer(
        id,
        _world.spawnPlayer(position: spawn),
        spawn,
      );
      _players[id] = player;
      _bodyToPlayer[player.character.body] = id;
      slot++;
    }
  }

  /// The arena data driving this simulation.
  final HammerArenaMap map;

  /// Alive count the round completes at (show-schedule property).
  final int quota;

  /// Ticks after which the round is complete with every remaining
  /// survivor (hammer-dodge.md § Qualification timeout).
  final int timeoutTicks;

  /// Timeout in ticks derived from the domain spec's 60 s round
  /// timeout at the fixed tick rate.
  static int get defaultTimeoutTicks =>
      (const HammerDodge().spec.timeoutMs / 1000 * PhysicsConsts.tickRate)
          .round();

  final CharacterWorld _world = CharacterWorld();
  final Map<PlayerId, _ArenaPlayer> _players = {};
  final Map<Body, PlayerId> _bodyToPlayer = {};
  late final BuiltArena _arena;
  final StreamController<RoundEvent> _eventSink =
      StreamController<RoundEvent>.broadcast(sync: true);

  int _tickCount = 0;
  bool _complete = false;
  int _eliminations = 0;

  /// Raw round events in emission order (synchronous broadcast:
  /// listeners observe each tick's events before the next one).
  @override
  Stream<RoundEvent> get events => _eventSink.stream;

  /// Current simulation tick (one per world step).
  int get currentTick => _tickCount;

  /// Whether the round ended: the alive count reached (or crossed)
  /// the quota, or the timeout ran out.
  @override
  bool get isComplete => _complete;

  /// Arenas have no course anchor (architecture doc § 3).
  @override
  double? get progressAnchorX => null;

  /// Platform radius at the current elapsed time per the shrink
  /// schedule.
  double get currentShrinkRadius => map.shrink.radiusAt(
        map.platformRadius,
        _tickCount * PhysicsConsts.fixedDt,
      );

  /// Tiers still standing (outermost drops first).
  int get activeTierCount => _arena.activeTierCount;

  /// Players still in the arena, spawn order.
  List<PlayerId> get survivorIds => [
    for (final player in _players.values)
      if (player.alive) player.id,
  ];

  /// Whether [playerId] is still in the arena.
  bool isAlive(PlayerId playerId) => _player(playerId).alive;

  /// The underlying Forge2D body of [playerId] (renderers, tests).
  /// Throws [StateError] for eliminated players — their bodies are
  /// destroyed, not merely moved.
  Body bodyOf(PlayerId playerId) {
    final player = _player(playerId);
    if (!player.alive) {
      throw StateError('player $playerId is eliminated');
    }
    return player.character.body;
  }

  /// Snapshot pose of [playerId], or null when eliminated (their
  /// body is gone).
  @override
  PlayerPose? poseOf(PlayerId playerId) {
    final player = _player(playerId);
    if (!player.alive) {
      return null;
    }
    final body = player.character.body;
    return (
      x: body.position.x,
      y: body.position.y,
      angle: body.angle,
      vx: body.linearVelocity.x,
      vy: body.linearVelocity.y,
    );
  }

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
  /// without an entry this tick idle (no input). Once the round is
  /// complete the simulation is frozen.
  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (_complete) {
      return;
    }
    for (final player in _players.values) {
      if (!player.alive) {
        continue;
      }
      final input = inputs[player.id];
      if (input == null) {
        continue;
      }
      _applyInput(player.character, input);
    }
    _world.step();
    _tickCount++;
    // Shrink and rim guards run on the just-elapsed time: a tier
    // whose radius the rim passed during this step drops now, and
    // the kill radius follows the new rim.
    final currentRadius = currentShrinkRadius;
    _arena
      ..applyShrink(currentRadius)
      ..pollSensors();
    _postStepGuards(currentRadius);
    // The quota counts once eliminations actually happened: a field
    // at or below the quota from the start must still run to its
    // timeout. Crossing (below quota in one tick) completes the same
    // tick — the victims' shared qualification is domain-side.
    if ((_eliminations > 0 && survivorIds.length <= quota) ||
        _tickCount >= timeoutTicks) {
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

  /// Explosion guard (silent respawn) then the rim guard: a player
  /// whose center leaves the kill radius — which follows the
  /// shrinking rim — has fallen off the platform. Eliminated, body
  /// destroyed (hammer-dodge.md § Qualification).
  void _postStepGuards(double currentRadius) {
    final killRadius = map.killRadiusFor(currentRadius);
    for (final player in _players.values) {
      if (!player.alive) {
        continue;
      }
      if (player.character.needsRespawn) {
        _recoverAtSpawn(player);
        continue;
      }
      if (player.character.body.position.length > killRadius) {
        _eliminate(player);
      }
    }
  }

  void _recoverAtSpawn(_ArenaPlayer player) {
    final body = player.character.body;
    player.character
      ..needsRespawn = false
      ..grounded = false;
    body
      ..setTransform(player.spawnAnchor, 0)
      ..linearVelocity.setZero()
      ..angularVelocity = 0;
  }

  void _eliminate(_ArenaPlayer player) {
    player.alive = false;
    _eliminations++;
    _bodyToPlayer.remove(player.character.body);
    _world.players.remove(player.character);
    _world.forgeWorld.destroyBody(player.character.body);
    _eventSink.add(PlayerEliminated(tick: _tickCount, playerId: player.id));
  }

  _ArenaPlayer _player(PlayerId playerId) {
    final player = _players[playerId];
    if (player == null) {
      throw ArgumentError.value(playerId, 'playerId', 'unknown player');
    }
    return player;
  }

  /// Kill-ring or mallet-head hit: same elimination as the rim guard
  /// (idempotent — first one wins).
  void _onArenaHit(PlayerId playerId) {
    final player = _players[playerId];
    if (player == null || !player.alive) {
      return;
    }
    _eliminate(player);
  }
}
