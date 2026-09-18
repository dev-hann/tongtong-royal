import 'dart:async';

import 'package:app/game/arenas/hammer/hammer_builder.dart';
import 'package:app/game/arenas/hammer/hammer_map.dart';
import 'package:app/game/character_world.dart';
import 'package:app/game/player_character.dart';
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

  /// True until the player leaves the arena (fall or fling).
  bool alive = true;
}

/// Round runner for a Hammer Dodge arena (GDD § 4.2): owns the
/// [CharacterWorld], the built arena and the players, advances the
/// simulation one fixed dt per tick and emits raw domain
/// [RoundEvent]s ([PlayerEliminated] only). Judging — placement
/// from elimination order — belongs to the domain resolver.
///
/// Elimination is final: the body is destroyed, there are no
/// checkpoints and no respawns into play (survival archetype). The
/// explosion guard still silently recovers a corrupted body back to
/// its spawn anchor (architecture doc § 5, no domain event).
final class HammerSimulation {
  /// Creates the simulation for [map], spawning every player on the
  /// map's spawn arc, with the GDD timeout (60 s).
  HammerSimulation({
    required HammerArenaMap map,
    required Iterable<PlayerId> playerIds,
  }) : this.forTesting(
         map: map,
         playerIds: playerIds,
         timeoutTicks: defaultTimeoutTicks,
       );

  /// Same as the default constructor, with an injectable timeout
  /// (tests shrink it instead of waiting out 60 s of ticks).
  @visibleForTesting
  HammerSimulation.forTesting({
    required this.map,
    required Iterable<PlayerId> playerIds,
    required this.timeoutTicks,
  }) {
    _arena = HammerArenaBuilder(onPlayerEliminated: _onKillRingHit).build(
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

  /// Ticks after which the round is complete with every remaining
  /// survivor (GDD § 7.5).
  final int timeoutTicks;

  /// Timeout in ticks derived from the GDD § 4.2 60 s round timeout
  /// at the fixed tick rate.
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
  Stream<RoundEvent> get events => _eventSink.stream;

  /// Current simulation tick (one per world step).
  int get currentTick => _tickCount;

  /// Whether the round ended: one player remains (or none), or the
  /// timeout was reached with the survivors still standing.
  bool get isComplete => _complete;

  /// Players still in the arena, spawn order.
  List<PlayerId> get survivorIds => [
    for (final player in _players.values)
      if (player.alive) player.id,
  ];

  /// Sole remaining player after completion; null on timeout with
  /// multiple survivors or a same-tick wipe (GDD § 7.5, § 7.7).
  PlayerId? get winnerId {
    if (!_complete) {
      return null;
    }
    final survivors = survivorIds;
    return survivors.length == 1 ? survivors.single : null;
  }

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

  /// Releases the event stream.
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
    _arena.pollSensors();
    _postStepGuards();
    // Last-standing (or same-tick wipe, GDD § 7.7) only counts once
    // an elimination actually happened — a one-player round must
    // still run to its timeout.
    if ((_eliminations > 0 && survivorIds.length <= 1) ||
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

  /// Explosion guard (silent respawn) then the arena-out check:
  /// a player whose center leaves the kill radius has fallen off
  /// the platform (GDD § 4.2) — eliminated, body destroyed.
  void _postStepGuards() {
    for (final player in _players.values) {
      if (!player.alive) {
        continue;
      }
      if (player.character.needsRespawn) {
        _recoverAtSpawn(player);
        continue;
      }
      if (player.character.body.position.length > map.killRadius) {
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

  /// Kill-ring sensor hit: same elimination as the radial guard
  /// (idempotent — first one wins).
  void _onKillRingHit(PlayerId playerId) {
    final player = _players[playerId];
    if (player == null || !player.alive) {
      return;
    }
    _eliminate(player);
  }
}
