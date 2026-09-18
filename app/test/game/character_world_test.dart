import 'package:app/game/character_world.dart';
import 'package:app/game/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Headless physics fixtures. Every simulation steps manually at
/// [PhysicsConsts.fixedDt] — no wall clock, no futures (testing doc § 4).
CharacterWorld _settledGroundedSim() {
  final sim = CharacterWorld()
    ..addStaticBox(
      center: Vector2(0, -0.5),
      width: 20,
      height: 1,
    )
    ..spawnPlayer(
      position: Vector2(
        0,
        PlayerCharacter.heightMeters / 2 + 0.01,
      ),
    );
  for (var i = 0; i < 30; i++) {
    sim.step();
  }
  return sim;
}

void main() {
  group('CharacterWorld physics', () {
    test('grounded flag is set after settling on static ground', () {
      final sim = _settledGroundedSim();

      expect(sim.players.single.grounded, isTrue);
    });

    test('applyMove reaches moveMaxSpeed and never exceeds it', () {
      final sim = _settledGroundedSim();
      final player = sim.players.single;
      var maxObserved = 0.0;

      for (var i = 0; i < 300; i++) {
        player.applyMove(Vector2(1, 0));
        sim.step();
        final vx = player.body.linearVelocity.x;
        if (vx > maxObserved) {
          maxObserved = vx;
        }
      }

      final maxSpeedCap = predicate<double>(
        (v) => v <= PhysicsConsts.moveMaxSpeed + 1e-4,
        'at most moveMaxSpeed',
      );
      expect(maxObserved, maxSpeedCap);
      expect(
        player.body.linearVelocity.x,
        greaterThan(PhysicsConsts.moveMaxSpeed - 0.1),
      );
    });

    test('jump lifts the player and gravity restores grounding', () {
      final sim = _settledGroundedSim();
      final player = sim.players.single;
      final startY = player.body.position.y;

      player.jump();
      sim.step();

      const takeoffSpeed = PhysicsConsts.jumpImpulse /
          PlayerCharacter.referenceMassKg;
      expect(
        player.body.linearVelocity.y,
        greaterThan(takeoffSpeed * 0.9),
      );

      var sawAirborne = false;
      var peakY = player.body.position.y;
      for (var i = 0; i < 300; i++) {
        sim.step();
        if (!player.grounded) {
          sawAirborne = true;
        }
        if (player.body.position.y > peakY) {
          peakY = player.body.position.y;
        }
      }

      expect(sawAirborne, isTrue);
      expect(peakY - startY, greaterThan(1.0));
      expect(player.grounded, isTrue);
      expect(player.body.linearVelocity.y, lessThan(0.5));
      expect(player.body.position.y, closeTo(startY, 0.05));
    });

    test('dash cannot push velocity beyond maxLinearVelocity', () {
      final sim = CharacterWorld(gravity: Vector2.zero());
      final player = sim.spawnPlayer()..dash(Vector2(1, 0));
      sim.step();

      const dashSpeed = PhysicsConsts.dashImpulse /
          PlayerCharacter.referenceMassKg;
      expect(player.body.linearVelocity.x, closeTo(dashSpeed, 1e-6));

      player
        ..body.linearVelocity
            .setFrom(Vector2(PhysicsConsts.maxLinearVelocity, 0))
        ..dash(Vector2(1, 0));
      sim.step();

      expect(
        player.body.linearVelocity.length,
        closeTo(PhysicsConsts.maxLinearVelocity, 1e-6),
      );
    });

    test('max-speed dash does not tunnel through a min-thickness wall', () {
      final sim = CharacterWorld();
      const wallX = 3.0;
      sim.addStaticBox(
        center: Vector2(wallX, 1.5),
        width: PhysicsConsts.minWallThickness,
        height: 4,
      );
      final player = sim.spawnPlayer(position: Vector2(0, 1.5));

      player.body.linearVelocity
          .setFrom(Vector2(PhysicsConsts.maxLinearVelocity, 0));
      var maxX = player.body.position.x;
      for (var i = 0; i < 30; i++) {
        sim.step();
        final x = player.body.position.x;
        if (x > maxX) {
          maxX = x;
        }
      }

      const wallNearFace = wallX - PhysicsConsts.minWallThickness / 2;

      const restCenterX =
          wallNearFace - PlayerCharacter.widthMeters / 2;
      expect(maxX, greaterThan(restCenterX - 0.1));
      expect(maxX, lessThan(wallNearFace));
      expect(player.needsRespawn, isFalse);
    });

    test('NaN velocity flags respawn and is zeroed by the tick guard', () {
      final sim = _settledGroundedSim();
      final player = sim.players.single;

      player.body.linearVelocity.setValues(double.nan, 0);
      sim.step();

      expect(player.needsRespawn, isTrue);
      expect(player.body.linearVelocity.x, 0.0);
      expect(player.body.linearVelocity.y.isFinite, isTrue);
      expect(player.body.position.y.isFinite, isTrue);
    });
  });
}
