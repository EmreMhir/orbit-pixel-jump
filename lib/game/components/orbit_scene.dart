import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import '../orbit_game.dart';
import '../../core/game_rules.dart';

class OrbitScene extends Component with HasGameReference<OrbitGame> {
  OrbitScene() : super(priority: -100);
  final _stars = List.generate(90, (index) {
    final random = math.Random(index * 997 + 42);
    return (
      random.nextDouble() * 400,
      random.nextDouble() * 800,
      random.nextDouble() * 0.5 + 0.2,
      index % 9 == 0 ? 3.0 : 1.5,
    );
  });
  static const _tints = [
    Color(0xff070d20),
    Color(0xff110d26),
    Color(0xff071c22),
    Color(0xff1c1022),
  ];
  final Map<int, Picture> _backgrounds = {};
  final _activeRing = Paint()
    ..color = const Color(0xff408e96)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final _twinkle = Paint();
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.reducedMotion) _time += dt;
  }

  Picture _recordBackground(int tintIndex) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final tint = _tints[tintIndex];
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 800), Paint()..color = tint);
    canvas.drawCircle(
      const Offset(200, 400),
      205,
      Paint()
        ..shader = Gradient.radial(const Offset(200, 400), 205, [
          const Color(0xff114650).withValues(alpha: 0.3),
          tint.withValues(alpha: 0),
        ]),
    );
    final starPaint = Paint();
    for (final star in _stars) {
      starPaint.color = const Color(0xffc7d9ff).withValues(alpha: star.$3);
      canvas.drawRect(
        Rect.fromLTWH(star.$1, star.$2, star.$4, star.$4),
        starPaint,
      );
    }
    final ringPaint = Paint()
      ..color = const Color(0xff26304b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in GameRules.radii) {
      canvas.drawCircle(const Offset(200, 400), radius, ringPaint);
    }
    canvas.save();
    canvas.translate(200, 400);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      const Rect.fromLTWH(-10, -10, 20, 20),
      Paint()..color = const Color(0xff164650),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-5, -5, 10, 10),
      Paint()..color = const Color(0xff70fff1),
    );
    canvas.restore();
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final tintIndex = (game.run.level - 1) % _tints.length;
    canvas.drawPicture(
      _backgrounds.putIfAbsent(tintIndex, () => _recordBackground(tintIndex)),
    );
    if (!game.reducedMotion) {
      // Only ten highlighted stars animate; the gradient and full field are cached.
      for (var i = 0; i < _stars.length; i += 9) {
        final star = _stars[i];
        _twinkle.color = const Color(
          0xffc7d9ff,
        ).withValues(alpha: (math.sin(_time * 0.6 + star.$1) + 1) * 0.08);
        canvas.drawRect(
          Rect.fromLTWH(star.$1, star.$2, star.$4, star.$4),
          _twinkle,
        );
      }
    }
    if (game.run.state != OrbitState.menu) {
      canvas.drawCircle(
        const Offset(200, 400),
        GameRules.radii[game.run.ring],
        _activeRing,
      );
    }
  }

  @override
  void onRemove() {
    for (final picture in _backgrounds.values) {
      picture.dispose();
    }
    _backgrounds.clear();
    super.onRemove();
  }
}
