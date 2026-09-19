import 'dart:async';

import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/course/course_map.dart';
import 'package:app/game/round_simulation.dart';
import 'package:app/game/view/race_game_view.dart'
    show IdleInputSource, InputSource;
import 'package:app/net/host/host_runtime.dart' show HostRuntime;
import 'package:app/net/host/round_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Grounded approximation threshold, meters per second: a body whose
/// vertical speed stays below this reads as supported. Rationale
/// (approximation — [RoundSimulation] does not expose ground
/// contacts): gravity ([PhysicsConsts.gravityMagnitude]) adds ~0.17
/// m/s per tick to a free-falling body, so any ballistic arc crosses
/// this within ~3 ticks, while resting contact leaves |vy| near zero.
const double groundedSpeedEpsilonMeters = 0.5;

/// One full solo round: the simulation, its bot brains and the
/// per-tick glue between them (GDD § 9.2: bots run host-side, one
/// decision per tick). Judges nothing — placements come from
/// [resolveRound] over the raw collected events (architecture doc
/// § 2).
///
/// Ticking is split so both hosts work: [buildInputs] runs before a
/// step, [postTick] after it. The race game view (Flame loop)
/// calls the halves separately; [tick] runs both for headless
/// rounds.
final class SoloRoundDriver {
  /// Creates a driver over [simulation]. [map] is the map data the
  /// simulation was built from (bot hazard observations derive from
  /// its hammer specs).
  SoloRoundDriver({
    required this.simulation,
    required this.game,
    required this.roundIndex,
    required this.roster,
    required this.humanId,
    required this.brains,
    required this.map,
    required this.onRoundComplete,
    InputSource? humanInput,
  }) : humanInput = humanInput ?? IdleInputSource() {
    _eventsSubscription = simulation.events.listen(_roundEvents.add);
  }

  /// The round's simulation (any archetype).
  final RoundSimulation simulation;

  /// Domain game the round resolves through.
  final MiniGame game;

  /// Zero-based round index inside the match.
  final int roundIndex;

  /// Every seat for the round (human + bots).
  final Set<PlayerId> roster;

  /// The human seat.
  final PlayerId humanId;

  /// Bot seats to their brains (fed once per tick).
  final Map<PlayerId, BotBrain> brains;

  /// Map data behind [simulation] (hazard observations).
  final Object map;

  /// Fires exactly once when the round ends (completion or timeout)
  /// with the domain-resolved result.
  final void Function(RoundResult result) onRoundComplete;

  /// Source of the human's per-tick input; the play view injects the
  /// touch overlay here, tests inject stubs.
  InputSource humanInput;

  final List<RoundEvent> _roundEvents = [];
  final List<ProgressSample> _samples = [];
  StreamSubscription<RoundEvent>? _eventsSubscription;
  int _tickCount = 0;
  bool _over = false;

  /// Round timeout in ticks ([MiniGameSpec.timeoutMs] at the fixed
  /// rate — same conversion as the networked host path).
  late final int timeoutTicks = HostRuntime.timeoutTicksFor(game);

  /// Ticks executed by this driver.
  int get tickCount => _tickCount;

  /// Whether the round already ended; further ticking is inert.
  bool get isRoundOver => _over;

  /// Collected raw events, in emission order.
  @visibleForTesting
  List<RoundEvent> get collectedEvents => List.unmodifiable(_roundEvents);

  /// Builds the full per-tick input map: the human's sample plus one
  /// decision per live bot from a [BotObservation] of the current
  /// simulation state. Eliminated bots (no body) get no entry and
  /// idle inside the simulation.
  Map<PlayerId, PlayerInputState> buildInputs() {
    if (_over) {
      return const {};
    }
    final inputs = <PlayerId, PlayerInputState>{humanId: humanInput.sample()};
    for (final entry in brains.entries) {
      final pose = _poseOfOrNull(entry.key);
      if (pose == null) {
        continue;
      }
      inputs[entry.key] = entry.value.decide(_observation(entry.key, pose));
    }
    return inputs;
  }

  /// Post-step bookkeeping: tick counter, progress sampling (race
  /// anchor only, same cadence as the networked host) and the
  /// completion/timeout check that ends the round exactly once.
  void postTick() {
    if (_over) {
      return;
    }
    _tickCount++;
    _sampleProgress();
    if (simulation.isComplete || _tickCount >= timeoutTicks) {
      _over = true;
      onRoundComplete(finish());
    }
  }

  /// One full headless tick (rounds without a Flame loop):
  /// inputs, step, bookkeeping.
  void tick() {
    if (_over) {
      return;
    }
    simulation.tickInputs(buildInputs());
    postTick();
  }

  /// Resolves the round through the domain from everything collected
  /// so far. Pure plumbing into [resolveRound].
  RoundResult finish() {
    return resolveRound(
      game,
      RoundEvents(roundIndex: roundIndex, events: _roundEvents.toList()),
      RoundData(roster: roster, progressSamples: _samples.toList()),
    );
  }

  /// Cancels the event subscription and releases the simulation.
  /// Idempotent.
  void dispose() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    simulation.dispose();
  }

  BotObservation _observation(PlayerId botId, BotPose pose) {
    final nearbyPlayers = <BotPose>[];
    for (final other in roster) {
      if (other == botId) {
        continue;
      }
      final otherPose = _poseOfOrNull(other);
      if (otherPose != null && _nearby(pose, otherPose)) {
        nearbyPlayers.add(otherPose);
      }
    }
    final nearbyHazards = <BotHazard>[];
    for (final hazard in _hazardStates()) {
      final dx = hazard.x - pose.x;
      final dy = hazard.y - pose.y;
      if (dx * dx + dy * dy <= awarenessRadius * awarenessRadius) {
        nearbyHazards.add(hazard);
      }
    }
    return BotObservation(
      tick: _tickCount,
      self: pose,
      grounded: pose.vy.abs() < groundedSpeedEpsilonMeters,
      nearbyPlayers: nearbyPlayers,
      nearbyHazards: nearbyHazards,
    );
  }

  BotPose? _poseOfOrNull(PlayerId id) {
    final pose = simulation.poseOf(id);
    if (pose == null) {
      return null;
    }
    return (x: pose.x, y: pose.y, vx: pose.vx, vy: pose.vy);
  }

  /// True when [other] stands within [awarenessRadius] of [self].
  static bool _nearby(BotPose self, BotPose other) {
    final dx = other.x - self.x;
    final dy = other.y - self.y;
    return dx * dx + dy * dy <= awarenessRadius * awarenessRadius;
  }

  /// Live hazard arms approximated by deterministic kinematics from
  /// the map specs (the simulations do not expose arm bodies):
  /// `angle = initialAngle + angularSpeed * tick * fixedDt` — exactly
  /// how the builders set the arms in motion.
  Iterable<BotHazard> _hazardStates() sync* {
    final specs = switch (map) {
      final CourseMap courseMap => courseMap.hammers,
      _ => const <HammerSpec>[],
    };
    for (final spec in specs) {
      yield (
        x: spec.pivot.x,
        y: spec.pivot.y,
        angle:
            spec.initialAngle +
            spec.angularSpeed * _tickCount * PhysicsConsts.fixedDt,
        angularVelocity: spec.angularSpeed,
      );
    }
  }

  /// Progress sampling mirrors the networked host: every
  /// [PhysicsConsts.progressSampleIntervalTicks]th round tick, race
  /// anchor only.
  void _sampleProgress() {
    final anchorX = simulation.progressAnchorX;
    if (anchorX == null ||
        _tickCount % PhysicsConsts.progressSampleIntervalTicks != 0) {
      return;
    }
    for (final id in roster) {
      final x = simulation.poseOf(id)?.x;
      if (x == null) {
        continue;
      }
      _samples.add(
        ProgressSample(tick: _tickCount, playerId: id, distance: x - anchorX),
      );
    }
  }
}
