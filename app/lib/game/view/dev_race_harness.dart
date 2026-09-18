import 'package:app/game/course/course_map.dart';
import 'package:app/game/course/race_simulation.dart';
import 'package:app/game/view/game_playground.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Developer harness: builds a seeded single-player race, runs it in
/// a [GamePlayground] and offers a Restart button that rebuilds the
/// simulation from the same seed.
///
/// Milestone-1 stand-in for the networked round host; contains no
/// rules (the button rebuilds physics state, nothing more).
final class DevRaceHarness extends StatefulWidget {
  /// Creates the harness for a [CourseMap.trapRace] seeded with
  /// [mapSeed].
  const DevRaceHarness({
    required this.mapSeed,
    this.localPlayerId = 'p1',
    this.onFinishEvent,
    super.key,
  });

  /// Key of the Restart button (tests).
  static const Key restartButtonKey = Key('dev_race_restart');

  /// Seed of the rebuilt course.
  final int mapSeed;

  /// Single (local) player id.
  final PlayerId localPlayerId;

  /// Optional passthrough of raw finish events.
  final void Function(PlayerFinished event)? onFinishEvent;

  @override
  State<DevRaceHarness> createState() => _DevRaceHarnessState();
}

final class _DevRaceHarnessState extends State<DevRaceHarness> {
  late RaceSimulation _simulation;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _simulation = _buildSimulation();
  }

  @override
  void dispose() {
    _simulation.dispose();
    super.dispose();
  }

  RaceSimulation _buildSimulation() => RaceSimulation(
    map: CourseMap.trapRace(widget.mapSeed),
    playerIds: [widget.localPlayerId],
  );

  void _restart() {
    final old = _simulation;
    _simulation = _buildSimulation();
    _generation++;
    setState(() {});
    // Dispose after the frame so the unmounted playground's ticker
    // can never step a closed simulation.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: KeyedSubtree(
            key: ValueKey<int>(_generation),
            child: GamePlayground(
              simulation: _simulation,
              localPlayerId: widget.localPlayerId,
              map: _simulation.map,
              onFinishEvent: widget.onFinishEvent,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton(
            key: DevRaceHarness.restartButtonKey,
            onPressed: _restart,
            child: const Text('Restart'),
          ),
        ),
      ],
    );
  }
}
