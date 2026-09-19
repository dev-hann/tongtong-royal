import 'package:app/game/bots/bot_brain.dart' show awarenessRadius;
import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/game/controls/steering.dart';
import 'package:app/game/round_simulation.dart';
import 'package:app/game/view/race_game_view.dart' show InputSource;
import 'package:tongtong_shared/tongtong_shared.dart';

/// [InputSource] for the one-button controls (GDD § 3): each
/// [sample] observes the local player's pose (plus nearby roster
/// bodies, contact-level only — same awareness contract as the
/// bots) and hands it to [ActionInputController.sampleFor] together
/// with the game's steering policy. Zero Flutter logic — the button
/// widget talks to the controller, this source only reads the
/// simulation.
final class AutoInputSource implements InputSource {
  /// Creates the source for [gameId]. [controller] must already
  /// carry the steering policy for [gameId] when the game needs a
  /// map-bound one; [roster] lists every seat so nearby
  /// players can be observed.
  AutoInputSource({
    required this.gameId,
    required this.controller,
    required this.simulation,
    required this.humanId,
    required Iterable<PlayerId> roster,
  }) : _roster = List.unmodifiable(roster);

  /// Minigame whose steering policy samples here.
  final String gameId;

  /// Button + steering owner.
  final ActionInputController controller;

  /// Simulation whose poses are observed.
  final RoundSimulation simulation;

  /// The observed (human) seat.
  final PlayerId humanId;

  /// All seats (human + everyone else).
  final List<PlayerId> _roster;

  int _tick = 0;

  @override
  PlayerInputState sample() {
    final self = simulation.poseOf(humanId);
    if (self == null) {
      // No body (e.g. eliminated in the survival archetype): idle
      // input — same convention as a missing tick-inputs entry.
      _tick++;
      return PlayerInputState();
    }
    final observation = SteeringObservation(
      tick: _tick++,
      selfX: self.x,
      selfY: self.y,
      selfVx: self.vx,
      selfVy: self.vy,
      nearbyPlayers: _nearbyPlayers(self),
    );
    return controller.sampleFor(gameId, observation);
  }

  List<SteeringPlayerPosition> _nearbyPlayers(PlayerPose self) {
    final nearby = <SteeringPlayerPosition>[];
    for (final id in _roster) {
      if (id == humanId) {
        continue;
      }
      final pose = simulation.poseOf(id);
      if (pose == null) {
        continue;
      }
      final dx = pose.x - self.x;
      final dy = pose.y - self.y;
      if (dx * dx + dy * dy <= awarenessRadius * awarenessRadius) {
        nearby.add((x: pose.x, y: pose.y));
      }
    }
    return nearby;
  }
}
