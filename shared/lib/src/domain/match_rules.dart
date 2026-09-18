/// Match-level game rules from the GDD (docs/01-game-design.md § 2, § 7.1).
abstract final class MatchRules {
  /// A match is 5 rounds (GDD § 2).
  static const int roundCount = 5;

  /// Minimum players to start a match (GDD § 7.1).
  static const int minPlayers = 2;

  /// Maximum players in a room (GDD § 1).
  static const int maxPlayers = 4;
}
