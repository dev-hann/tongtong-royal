import 'dart:async';

import 'package:app/game/round_simulation.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Scripted [RoundSimulation] for solo-mode tests: counts ticks,
/// records the input maps it was fed, emits scripted events and
/// completes after a configurable tick count.
class FakeSoloSim implements RoundSimulation {
  /// Creates a fake over [roster] completing after [completeAfterTicks].
  FakeSoloSim({
    required this.minigameId,
    required Iterable<PlayerId> roster,
    this.completeAfterTicks = 2,
    this.progressAnchor,
  }) : roster = List.unmodifiable(roster);

  /// Minigame id this sim claims to bind (mirrors the factory arg).
  final MiniGameId minigameId;

  /// Roster the sim was built for.
  final List<PlayerId> roster;

  /// Ticks after which [isComplete] flips true (null: never).
  final int? completeAfterTicks;

  /// Fixed progress anchor (null: arena archetype, no sampling).
  final double? progressAnchor;

  final StreamController<RoundEvent> _sink =
      StreamController<RoundEvent>.broadcast(sync: true);

  /// Input maps received per tick, in order.
  final List<Map<PlayerId, PlayerInputState>> inputLog = [];

  /// Poses returned by [poseOf]; defaults to a static row per player.
  final Map<PlayerId, PlayerPose> poses = {};

  /// Players whose [poseOf] reports null (eliminated bodies).
  final Set<PlayerId> eliminated = {};

  int _tickCount = 0;

  /// Ticks executed so far.
  int get tickCount => _tickCount;

  /// Emits a raw event on the broadcast stream.
  void emit(RoundEvent event) => _sink.add(event);

  @override
  Stream<RoundEvent> get events => _sink.stream;

  @override
  bool get isComplete =>
      completeAfterTicks != null && _tickCount >= completeAfterTicks!;

  @override
  double? get progressAnchorX => progressAnchor;

  @override
  PlayerPose? poseOf(PlayerId playerId) {
    if (eliminated.contains(playerId)) {
      return null;
    }
    if (poses.containsKey(playerId)) {
      return poses[playerId];
    }
    if (!roster.contains(playerId)) {
      return null;
    }
    final index = roster.indexOf(playerId);
    return (x: index * 2.0, y: 0, angle: 0, vx: 0, vy: 0);
  }

  @override
  void tickInputs(Map<PlayerId, PlayerInputState> inputs) {
    inputLog.add(Map.unmodifiable(inputs));
    _tickCount++;
  }

  @override
  void dispose() => _sink.close();
}
