import 'dart:async';

import 'package:app/game/character_world.dart';
import 'package:app/game/course/course_builder.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/racer_guards.dart';
import 'package:app/game/player_character.dart';
import 'package:app/game/round_simulation.dart';
import 'package:flutter/foundation.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

part 'race_final.dart';

/// Round runner for a race course (architecture doc § 2): owns the
/// [CharacterWorld], the built course and the players, advances one
/// fixed dt per tick, emits raw domain [RoundEvent]s — no judging.
///
/// Standard: falls respawn at the last checkpoint; completes when
/// every racer finished. FINAL ([RaceVariant.finalRound],
/// trap-race.md): no respawn — falls and hammer hits eliminate
/// (body destroyed, [PlayerEliminated]); completes at the first
/// finisher, one racer left alive, or the 60 s cap.
final class RaceSimulation implements CourseEvents, RoundSimulation {
  /// Creates the simulation for [map] in [variant] (default standard).
  RaceSimulation({
    required CourseMap map,
    required Iterable<PlayerId> playerIds,
    RaceVariant variant = RaceVariant.standard,
  }) : this.forTesting(
          map: map,
          playerIds: playerIds,
          stuckThresholdSeconds: PhysicsConsts.stuckThresholdSeconds,
          variant: variant,
        );

  /// Creates with injectable thresholds (tests shrink them).
  @visibleForTesting
  RaceSimulation.forTesting({
    required this.map,
    required Iterable<PlayerId> playerIds,
    required this.stuckThresholdSeconds,
    this.variant = RaceVariant.standard,
    this.finalTimeoutTicks = defaultFinalTimeoutTicks,
  }) {
    _course = CourseBuilder(events: this)
        .build(_world, map, resolvePlayer: _playerIdOfBody);
    final slots = map.effectiveSpawnPoints;
    var slot = 0;
    for (final id in playerIds) {
      final spawn = slots[slot % slots.length];
      final racer = _Racer(id, _world.spawnPlayer(position: spawn), spawn);
      _racers[id] = racer;
      _bodyToPlayer[racer.character.body] = id;
      slot++;
    }
  }

  /// FINAL round cap in ticks (trap-race.md § Qualification: 60 s).
  static const int defaultFinalTimeoutTicks = 60 * PhysicsConsts.tickRate;

  /// The course data driving this simulation.
  final CourseMap map;

  /// Stuck threshold in seconds for this simulation.
  final double stuckThresholdSeconds;

  /// Which variant this simulation runs.
  final RaceVariant variant;

  /// FINAL-mode internal timeout in ticks (standard mode leaves
  /// timeouts to the host runtime).
  final int finalTimeoutTicks;

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
  bool _complete = false;
  int _eliminations = 0;

  @override
  Stream<RoundEvent> get events => _eventSink.stream;

  /// Current simulation tick (one per world step).
  int get currentTick => _tickCount;

  /// Whether this simulation runs the FINAL variant.
  bool get isFinalVariant => variant == RaceVariant.finalRound;

  /// Racer body (renderers, tests). Throws [StateError] after a
  /// FINAL elimination — the body is destroyed, not moved.
  Body bodyOf(PlayerId playerId) {
    final racer = _racer(playerId);
    if (!racer.alive) {
      throw StateError('player $playerId is eliminated');
    }
    return racer.character.body;
  }

  /// Whether [playerId] already crossed the finish.
  bool hasFinished(PlayerId playerId) => _racer(playerId).finished;

  /// Whether [playerId] is still racing (false after a FINAL
  /// elimination; standard mode never eliminates).
  bool isAlive(PlayerId playerId) => _racer(playerId).alive;

  /// Standard mode: all racers finished. FINAL: first finisher,
  /// last survivor, or the 60 s cap.
  @override
  bool get isComplete =>
      isFinalVariant ? _complete : _racers.values.every((r) => r.finished);

  /// Race progress is measured from the spawn point's x.
  @override
  double? get progressAnchorX => map.spawnPoint.x;

  /// Snapshot pose of [playerId]; null for FINAL-mode eliminations.
  @override
  PlayerPose? poseOf(PlayerId playerId) {
    final racer = _racer(playerId);
    if (!racer.alive) {
      return null;
    }
    final b = racer.character.body;
    return (
      x: b.position.x,
      y: b.position.y,
      angle: b.angle,
      vx: b.linearVelocity.x,
      vy: b.linearVelocity.y,
    );
  }

  @override
  void dispose() => _eventSink.close();

  /// Applies [input] for [playerId] and advances the whole world one
  /// fixed dt (per-tick guards included, via [CharacterWorld.step]).
  void tick(PlayerId playerId, PlayerInputState input) {
    tickInputs({playerId: input});
  }

  /// Applies one input per player and advances one fixed dt (the
  /// host's batched entry point). Missing entries idle; a completed
  /// FINAL freezes the simulation.
  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    if (isComplete) {
      return;
    }
    _course.advanceWalls(_tickCount);
    for (final racer in _racers.values) {
      final input = inputs[racer.id];
      if (input == null || racer.finished || !racer.alive) {
        racer.moveInputActive = false;
        continue;
      }
      racer.moveInputActive = input.moveDir.length2 > 0;
      applyPlayerInput(racer.character, input);
    }
    _world.step();
    _tickCount++;
    _course.pollSensors(_tickCount);
    _postStepGuards();
    if (isFinalVariant) _maybeCompleteFinal();
  }

  void _postStepGuards() {
    for (final racer in _racers.values) {
      if (!racer.alive) {
        continue;
      }
      if (racer.character.needsRespawn) {
        // Explosion guard (architecture doc § 5): silent recovery,
        // no domain event; FINAL has no checkpoints so it recovers
        // at the spawn slot.
        _respawn(racer, atSpawn: isFinalVariant);
        continue;
      }
      if (!racer.finished && racer.character.body.position.y < map.killY) {
        _handleFall(racer);
      }
      _updateStuck(racer);
    }
  }

  void _updateStuck(_Racer racer) {
    if (!racer.alive) {
      return;
    }
    racer.stuck.observe(
      inputActive: racer.moveInputActive && !racer.finished,
      position: racer.character.body.position,
      thresholdSeconds: stuckThresholdSeconds,
    );
    if (racer.stuck.triggeredAt(stuckThresholdSeconds)) {
      // Stuck recovery (architecture doc § 5): not a fall, no
      // event; FINAL recovers at the spawn slot (physics recovery,
      // not a game respawn: the racer keeps racing).
      _respawn(racer, atSpawn: isFinalVariant);
    }
  }

  void _handleFall(_Racer racer) {
    if (isFinalVariant) return _eliminate(racer);
    _eventSink.add(PlayerFell(tick: _tickCount, playerId: racer.id));
    _respawn(racer);
  }

  void _respawn(_Racer racer, {bool atSpawn = false}) {
    final point = atSpawn
        ? racer.spawnAnchor
        : _respawnPoints[racer.respawnIndex];
    final character = racer.character;
    racer.stuck.reset(point);
    character
      ..needsRespawn = false
      ..grounded = false
      ..body.setTransform(point, 0)
      ..body.linearVelocity.setZero()
      ..body.angularVelocity = 0;
  }

  void _eliminate(_Racer racer) {
    if (!racer.alive) {
      return;
    }
    racer
      ..alive = false
      ..moveInputActive = false;
    _eliminations++;
    _bodyToPlayer.remove(racer.character.body);
    _world.players.remove(racer.character);
    _world.forgeWorld.destroyBody(racer.character.body);
    _eventSink.add(PlayerEliminated(tick: _tickCount, playerId: racer.id));
  }

  /// FINAL completion (trap-race.md): first finisher, one racer
  /// left alive (needs an elimination first), or the cap. Same-tick
  /// wipes complete too — shared-crown is domain-side (GDD § 7.2).
  void _maybeCompleteFinal() {
    final aliveCount = _racers.values.where((r) => r.alive).length;
    if (_racers.values.any((r) => r.finished) ||
        (_eliminations > 0 && aliveCount <= 1) ||
        _tickCount >= finalTimeoutTicks) {
      _complete = true;
    }
  }

  PlayerId? _playerIdOfBody(Body body) => _bodyToPlayer[body];

  _Racer _racer(PlayerId playerId) => _racers[playerId] ??
      (throw ArgumentError.value(playerId, 'playerId', 'unknown player'));

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

  @override
  void onPlayerHitByHammer(PlayerId playerId) {
    // Knockback-only in R1; elimination in the FINAL variant.
    if (isFinalVariant) _eliminate(_racer(playerId));
  }
}
