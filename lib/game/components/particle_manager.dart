import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import '../orbit_game.dart';

abstract final class ParticleManager {
  static void explode(OrbitGame game, Vector2 position) {
    final random = math.Random();
    game.world.add(
      ParticleSystemComponent(
        position: position.clone(),
        priority: 30,
        particle: Particle.generate(
          count: game.reducedMotion ? 10 : 36,
          lifespan: 0.65,
          generator: (_) {
            final direction = random.nextDouble() * 2 * math.pi;
            final velocity = 45 + random.nextDouble() * 160;
            final color = [
              const Color(0xff70fff1),
              const Color(0xffffc0a1),
              const Color(0xffff685f),
            ][random.nextInt(3)];
            return AcceleratedParticle(
              speed:
                  Vector2(math.cos(direction), math.sin(direction)) * velocity,
              acceleration: Vector2(0, 35),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final side = 4 * (1 - particle.progress) + 1;
                  canvas.drawRect(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: side,
                      height: side,
                    ),
                    Paint()
                      ..color = color.withValues(alpha: 1 - particle.progress),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    if (!game.reducedMotion) game.camera.shake();
  }
}

/// Flame 1.38 uses CameraComponent. This extension provides camera.shake().
extension OrbitCameraShake on CameraComponent {
  void shake() => viewfinder.add(_ScreenShake());
}

class _ScreenShake extends Component {
  double _elapsed = 0;
  late Vector2 _origin;
  late Viewfinder _viewfinder;
  final _random = math.Random();

  @override
  void onMount() {
    super.onMount();
    _viewfinder = parent! as Viewfinder;
    _origin = _viewfinder.position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= 0.3) {
      _viewfinder.position.setFrom(_origin);
      removeFromParent();
      return;
    }
    final amplitude = 5 * (1 - _elapsed / 0.3);
    _viewfinder.position.setValues(
      _origin.x + (_random.nextDouble() * 2 - 1) * amplitude,
      _origin.y + (_random.nextDouble() * 2 - 1) * amplitude,
    );
  }

  @override
  void onRemove() {
    _viewfinder.position.setFrom(_origin);
    super.onRemove();
  }
}
