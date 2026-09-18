import 'dart:async';

import 'package:app/game/character_world.dart';
import 'package:app/game/course/course_builder.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/player_character.dart';
import 'package:app/game/player_input.dart';
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Stuck-detection displacement threshold, meters.
///
/// Input-magnitude-derived measurement floor, not gameplay tuning:
/// with an active move input a player covers `moveMaxSpeed` (6 m/s),
/// while contact-solver jitter stays around 1e-2 m per tick. 0.25 m
/// per threshold window separates "pushing but blocked" (stuck) from
/// "making progress" for any sustained locomotion attempt, without
/// depending on the threshold duration (architecture doc § 5).
const double stuckDisplacementEpsilonMeters = 0.25;

/// Per-player race state. Thin wrapper: physics lives on
/// [PlayerCharacter], rules live nowhere (events only).
final class _Racer {
  _Racer(this.id, this.character, Vector2 spawnAnchor)
    : stuckReference = spawnAnchor.clone();

  final PlayerId id;
  final PlayerCharacter character;

  /// Index into the respawn point list (0 = spawn).
  int respawnIndex = 0;
  bool finished = false;
  bool moveInputActive = false;
  Vector2 stuckReference;
  double stuckElapsedSeconds = 0;
}

/// Round runner for a race course: owns the [CharacterWorld], the
/// built course and the players, advances the simulation one fixed
/// dt per tick and emits raw domain [RoundEvent]s (finish/fall).
/// No points, ranks, or judging here (architecture doc § 2).
final class RaceSimulation implements CourseEvents {
  /// Creates the simulation for [map] and spawns every player in
  /// [playerIds] at the map's spawn point.
  RaceSimulation({
    required CourseMap map,
    required Iterable<PlayerId> playerIds,
  }) : this.forTesting(
         map: map,
         playerIds: playerIds,
         stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
       );

  /// Same as the default constructor, with an injectable stuck
  /// threshold (tests shrink it instead of waiting 5 s of ticks).
  @visibleForTesting
  RaceSimulation.forTesting({
    required this.map,
    required Iterable<PlayerId> playerIds,
    required this.stuckThresholdSeconds,
  }) {
    _course = CourseBuilder(events: this)
        .build(_world, map, resolvePlayer: _playerIdOfBody);
    for (final id in playerIds) {
      final racer = _Racer(
        id,
        _world.spawnPlayer(position: map.spawnPoint),
        map.spawnPoint,
      );
      _racers[id] = racer;
      _bodyToPlayer[racer.character.body] = id;
    }
  }

  /// The course data driving this simulation.
  final CourseMap map;

  /// Stuck threshold in seconds for this simulation.
  final double stuckThresholdSeconds;

  final CharacterWorld _world = CharacterWorld();
  final Map<PlayerId, _Racer> _racers = {};
  final Map<Body, PlayerId> _bodyToPlayer = {};
  late final BuiltCourse _course;
  late final List<Vector2> _respawnPoints = [
    map.spawnPoint,
    ...map.checkpoints,
  ];
  final StreamController<RoundEvent> _eventSink =
      StreamController<RoundEvent>.broadcast(sync: true);

  int _tickCount = 0;

  /// Raw round events in emission order (synchronous broadcast:
  /// listeners observe each tick's events before the next one).
  Stream<RoundEvent> get events => _eventSink.stream;

  /// Current simulation tick (one per world step).
  int get currentTick => _tickCount;

  /// The underlying Forge2D body of [playerId] (renderers, tests).
  Body bodyOf(PlayerId playerId) => _racer(playerId).character.body;

  /// Whether [playerId] already crossed the finish.
  bool hasFinished(PlayerId playerId) => _racer(playerId).finished;

  /// Releases the event stream.
  void dispose() => _eventSink.close();

  /// Applies [input] for [playerId] and advances the whole world one
  /// fixed dt (per-tick guards included, via [CharacterWorld.step]).
  void tick(PlayerId playerId, PlayerInputState input) {
    tickInputs({playerId: input});
  }

  /// Applies one input per player and advances the world a single
  /// fixed dt — the host's batched per-tick entry point. Players
  /// without an entry this tick idle (no input).
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    for (final racer in _racers.values) {
      final input = inputs[racer.id];
      if (input == null || racer.finished) {
        racer.moveInputActive = false;
        continue;
      }
      racer.moveInputActive = input.moveDir.length2 > 0;
      _applyInput(racer.character, input);
    }
    _world.step();
    _tickCount++;
    _course.pollSensors(_tickCount);
    _postStepGuards();
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

  void _postStepGuards() {
    for (final racer in _racers.values) {
      if (racer.character.needsRespawn) {
        // Explosion guard (architecture doc § 5): respawn and log via
        // the event stream is not applicable — there is no explosion
        // domain event, and PlayerFell means a fall zone.
        _respawn(racer);
        continue;
      }
      if (!racer.finished && racer.character.body.position.y < map.killY) {
        _handleFall(racer);
      }
      _updateStuck(racer);
    }
  }

  void _updateStuck(_Racer racer) {
    final body = racer.character.body;
    if (!racer.moveInputActive || racer.finished) {
      racer
        ..stuckReference = body.position.clone()
        ..stuckElapsedSeconds = 0;
      return;
    }
    final displacement = (body.position - racer.stuckReference).length;
    if (displacement > stuckDisplacementEpsilonMeters) {
      racer
        ..stuckReference = body.position.clone()
        ..stuckElapsedSeconds = 0;
      return;
    }
    racer.stuckElapsedSeconds += PhysicsConsts.fixedDt;
    if (racer.stuckElapsedSeconds >= stuckThresholdSeconds) {
      // Stuck respawn (architecture doc § 5): same mechanics as a
      // fall respawn, but not a fall — no PlayerFell event.
      _respawn(racer);
    }
  }

  void _handleFall(_Racer racer) {
    _eventSink.add(PlayerFell(tick: _tickCount, playerId: racer.id));
    _respawn(racer);
  }

  void _respawn(_Racer racer) {
    final point = _respawnPoints[racer.respawnIndex];
    final character = racer.character;
    racer
      ..stuckReference = point.clone()
      ..stuckElapsedSeconds = 0;
    character
      ..needsRespawn = false
      ..grounded = false
      ..body.setTransform(point, 0)
      ..body.linearVelocity.setZero()
      ..body.angularVelocity = 0;
  }

  PlayerId? _playerIdOfBody(Body body) => _bodyToPlayer[body];

  _Racer _racer(PlayerId playerId) {
    final racer = _racers[playerId];
    if (racer == null) {
      throw ArgumentError.value(playerId, 'playerId', 'unknown player');
    }
    return racer;
  }

  @override
  void onPlayerFell(PlayerId playerId) => _handleFall(_racer(playerId));

  @override
  void onCheckpoint(PlayerId playerId, int checkpointIndex) {
    final racer = _racer(playerId);
    if (racer.finished) {
      return;
    }
    // Checkpoints trigger in any order; the respawn point is the
    // highest index touched (course rule from the architecture's
    // respawn semantics).
    final respawnIndex = checkpointIndex + 1;
    if (respawnIndex > racer.respawnIndex) {
      racer.respawnIndex = respawnIndex;
    }
  }

  @override
  void onPlayerFinished(int tick, PlayerId playerId) {
    final racer = _racer(playerId);
    if (racer.finished) {
      return;
    }
    racer.finished = true;
    _eventSink.add(PlayerFinished(tick: tick, playerId: playerId));
  }
}
