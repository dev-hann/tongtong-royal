import 'package:tongtong_shared/src/domain/game/trap_race.dart';
import 'package:tongtong_shared/src/domain/minigame.dart';
import 'package:tongtong_shared/src/domain/models.dart';

/// Dumb id-to-instance lookup over registered minigames.
///
/// Holds no rules: judging belongs to each [MiniGame]. `pool` feeds
/// round planning (GDD § 6: one minigame, no selection rule).
final class MinigameRegistry {
  /// Creates the registry over [games], which defaults to the single
  /// built-in MVP minigame (GDD § 4).
  const MinigameRegistry([List<MiniGame> games = const [TrapRace()]])
    : _games = games;

  final List<MiniGame> _games;

  /// Ids of the registered minigames, in registration order.
  List<MiniGameId> get pool => [for (final game in _games) game.id];

  /// Returns the minigame registered under [id].
  ///
  /// Throws [ArgumentError] when no registered minigame has [id].
  MiniGame byId(MiniGameId id) {
    for (final game in _games) {
      if (game.id == id) {
        return game;
      }
    }
    throw ArgumentError.value(id, 'id', 'unknown minigame id');
  }
}
