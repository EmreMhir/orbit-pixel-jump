import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '../orbit_game.dart';
import '../../core/game_rules.dart';
import 'player.dart';

class Obstacle extends SpriteComponent
    with HasGameReference<OrbitGame>, CollisionCallbacks {
  Obstacle({
    required Sprite sprite,
    required this.ring,
    required this.orbitAngle,
    required this.angularSpeed,
  }) : super(
         sprite: sprite,
         size: Vector2.all(26),
         anchor: Anchor.center,
         priority: 10,
       );
  final int ring;
  double orbitAngle;
  final double angularSpeed;

  @override
  Future<void> onLoad() async {
    paint.filterQuality = FilterQuality.none;
    add(
      CircleHitbox(
        radius: 9,
        position: Vector2.all(13),
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
    syncPosition();
  }

  void syncPosition() => position.setValues(
    200 + math.cos(orbitAngle) * GameRules.radii[ring],
    400 + math.sin(orbitAngle) * GameRules.radii[ring],
  );

  @override
  void update(double dt) {
    if (game.userPaused) return;
    super.update(dt);
    if (game.isPlaying || game.run.state == OrbitState.menu) {
      orbitAngle = GameRules.wrapAngle(
        orbitAngle + angularSpeed * dt * (game.isPlaying ? game.speed : 0.18),
      );
      angle += dt * angularSpeed * 0.55;
      syncPosition();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isRemoving) return;
    if (other is Player && other.alive && other.shieldRemaining <= 0) {
      game.die();
    }
  }
}
