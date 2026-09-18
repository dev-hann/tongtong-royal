/// All gameplay physics tuning constants for TongTong Royal.
///
/// Single source of truth: no gameplay numbers may be inlined anywhere
/// else (AGENTS.md § 6.4). World scale is 1 unit = 1 meter; players are
/// roughly 1.5 m tall bouncy bodies.
abstract final class PhysicsConsts {
  /// Simulation tick rate in hertz (ticks per second).
  static const int tickRate = 60;

  /// Fixed simulation timestep in seconds, the inverse of [tickRate].
  static const double fixedDt = 1 / tickRate;

  /// Gravity magnitude, meters per second squared (positive value;
  /// worlds apply it downward). Combined with [jumpImpulse] on a ~65 kg
  /// player this yields ~4.9 m/s takeoff, about 1.2 m of jump height.
  static const double gravityMagnitude = 10;

  /// Hard cap on player linear speed, meters per second. The host
  /// clamps every player body to this each tick.
  static const double maxLinearVelocity = 20;

  /// Hard cap on player angular speed, radians per second.
  static const double maxAngularVelocity = 15;

  /// Vertical jump impulse, newton-seconds. With a ~65 kg player this
  /// gives ~4.9 m/s takeoff, about 1.2 m of jump height.
  static const double jumpImpulse = 320;

  /// Horizontal dash impulse, newton-seconds (~4 m/s burst). The
  /// resulting velocity is still capped by the linear clamp.
  static const double dashImpulse = 260;

  /// Continuous ground movement force, newtons.
  static const double moveForce = 900;

  /// Ground run speed cap, meters per second.
  static const double moveMaxSpeed = 6;

  /// Minimum wall thickness, meters. Backstop against tunneling even
  /// with bullet-enabled player bodies at top dash speed.
  static const double minWallThickness = 0.3;

  /// Seconds of active input with near-zero displacement before a
  /// stuck player is respawned at the last checkpoint.
  static const double stuckThresholdSeconds = 5;

  /// Friction between a player body and static ground.
  static const double playerGroundFriction = 0.6;

  /// Friction between two player bodies.
  static const double playerPlayerFriction = 0.2;

  /// Restitution (bounciness) of player-vs-ground contacts.
  static const double restitutionGround = 0.35;

  /// Restitution (bounciness) of player-vs-player contacts. Bouncy
  /// casual feel: players ricochet off each other.
  static const double restitutionPlayer = 0.6;

  /// Magnitude, in meters, beyond which a position or velocity
  /// component counts as an explosion and triggers respawn.
  static const double worldBoundsTolerance = 500;
}
