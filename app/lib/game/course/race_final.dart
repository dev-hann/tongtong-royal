part of 'race_simulation.dart';

/// Which Trap Race variant a [RaceSimulation] runs.
enum RaceVariant {
  /// R1 standard course: falls respawn at the last checkpoint.
  standard,

  /// FINAL (`trap_race_final`): no respawn — falls and hammer hits
  /// eliminate (trap-race.md § Qualification FINAL).
  finalRound,
}

/// Per-player race state. Thin wrapper: physics lives on
/// [PlayerCharacter], rules live nowhere (events only).
final class _Racer {
  _Racer(this.id, this.character, this.spawnAnchor)
    : stuck = StuckTracker(spawnAnchor);

  final PlayerId id;
  final PlayerCharacter character;

  /// Slot this racer spawned on (silent-recovery target in the
  /// FINAL variant, which has no checkpoints).
  final Vector2 spawnAnchor;

  /// Index into the respawn point list (0 = spawn). Standard mode
  /// only.
  int respawnIndex = 0;
  bool finished = false;
  bool alive = true;
  bool moveInputActive = false;
  final StuckTracker stuck;
}
