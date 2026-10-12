import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import '../../core/game_rules.dart';
import '../orbit_game.dart';

class Player extends SpriteComponent with HasGameReference<OrbitGame> {
  Player(Sprite sprite)
    : super(
        sprite: sprite,
        size: Vector2.all(26),
        anchor: Anchor.center,
        priority: 20,
      );
  final _radialPosition = PositionComponent();
  MoveEffect? _jump;
  double orbitAngle = -math.pi / 2;
  double shieldRemaining = 0;
  bool jumping = false;
  bool alive = true;
  double get radius => _radialPosition.position.x;

  @override
  Future<void> onLoad() async {
    paint.filterQuality = FilterQuality.none;
    _radialPosition.position.x = GameRules.radii.first;
    add(_radialPosition);
    add(
      CircleHitbox(radius: 8, position: Vector2.all(13), anchor: Anchor.center),
    );
    syncPosition();
  }

  void reset({required int ring, double shield = 0}) {
    _jump?.removeFromParent();
    _jump = null;
    jumping = false;
    alive = true;
    shieldRemaining = shield;
    _radialPosition.position.setValues(GameRules.radii[ring], 0);
    syncPosition();
  }

  void jumpTo(int ring) {
    if (jumping || !alive || !game.isPlaying) return;
    jumping = true;
    // The effect animates a radial coordinate, leaving orbital rotation independent.
    _jump = MoveEffect.to(
      Vector2(GameRules.radii[ring], 0),
      EffectController(duration: GameRules.jumpDuration),
      onComplete: () {
        jumping = false;
        _jump = null;
        if (alive && game.isPlaying) game.onLanding();
      },
    );
    _radialPosition.add(_jump!);
  }

  void syncPosition() {
    position.setValues(
      200 + math.cos(orbitAngle) * radius,
      400 + math.sin(orbitAngle) * radius,
    );
    angle = orbitAngle + math.pi;
  }

  @override
  void update(double dt) {
    if (!alive || game.userPaused) return;
    super.update(dt);
    if (game.run.state == OrbitState.menu || game.isPlaying) {
      orbitAngle = GameRules.wrapAngle(
        orbitAngle + dt * (game.isPlaying ? 1.05 * game.speed : 0.3),
      );
      shieldRemaining = math.max(0, shieldRemaining - dt);
      syncPosition();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!alive) return;
    if (shieldRemaining > 0) {
      canvas.drawCircle(
        const Offset(13, 13),
        18,
        Paint()
          ..color = const Color(0xff70fff1).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    super.render(canvas);
  }
}
