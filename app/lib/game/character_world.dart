import 'package:app/game/player_character.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Owns a Forge2D [World] and steps it at [PhysicsConsts.fixedDt].
///
/// The unit-testable simulation surface: pure Forge2D, no Flame
/// widgets. The host ticks [step] once per simulation tick; it runs
/// the per-player guards (grounding, velocity clamps, explosive
/// checks) before and after the physics step so the solver never
/// sees corrupted state and every observed velocity is clamped.
class CharacterWorld {
  /// Creates the world with [standardGravity] unless [gravity] is
  /// given (tests may zero it).
  CharacterWorld({Vector2? gravity})
      : forgeWorld = World(gravity ?? standardGravity);

  /// Standard world gravity (1 unit = 1 meter, y up). Magnitude comes
  /// from [PhysicsConsts.gravityMagnitude].
  static Vector2 get standardGravity =>
      Vector2(0, -PhysicsConsts.gravityMagnitude);

  /// The Forge2D world. Exposed for map building (walls, kill
  /// sensors) and rendering.
  final World forgeWorld;

  /// Players currently simulated by this world.
  final List<PlayerCharacter> players = [];

  /// Spawns a [PlayerCharacter] at [position] (defaults to origin).
  PlayerCharacter spawnPlayer({Vector2? position}) {
    final player = PlayerCharacter(forgeWorld, position: position);
    players.add(player);
    return player;
  }

  /// Adds a static box (ground slab, wall, obstacle). Walls must be
  /// at least [PhysicsConsts.minWallThickness] thick — enforce that
  /// in map validation, not here.
  Body addStaticBox({
    required Vector2 center,
    required double width,
    required double height,
    double friction = PhysicsConsts.playerGroundFriction,
    double restitution = PhysicsConsts.restitutionGround,
  }) {
    final body = forgeWorld.createBody(
      BodyDef(position: center.clone()),
    );
    final shape = PolygonShape()..setAsBoxXY(width / 2, height / 2);
    body.createFixture(
      FixtureDef(shape, friction: friction, restitution: restitution),
    );
    return body;
  }

  /// Advances the simulation one fixed timestep.
  void step() {
    for (final player in players) {
      player
        ..updateGrounded()
        ..enforceLimits();
    }
    forgeWorld.stepDt(PhysicsConsts.fixedDt);
    for (final player in players) {
      player
        ..updateGrounded()
        ..enforceLimits();
    }
  }
}
