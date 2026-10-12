import 'dart:math' as math;

enum OrbitState { menu, playing, gameOver }

abstract final class GameRules {
  static const radii = <double>[52, 84, 116, 148, 180];
  static const jumpDuration = 0.16;
  static const reviveShield = 2.5;
  // A stalled frame may do at most six physics steps, avoiding a catch-up spiral.
  static const maxFrameTime = 1 / 20;
  static const physicsStep = 1 / 120;

  static double speed(int level, double seconds) =>
      (1 + (level - 1) * 0.10 + seconds * 0.002).clamp(1.0, 2.4);

  static int obstacleCount(int level, int ring) =>
      math.min(3, 1 + (level - 1) ~/ 3 + (ring == 4 && level > 1 ? 1 : 0));

  static double wrapAngle(double angle) => angle % (2 * math.pi);
}

/// A round can grant exactly one rewarded revive, even after rapid taps.
class RunProgress {
  OrbitState state = OrbitState.menu;
  int score = 0;
  int level = 1;
  int ring = 0;
  bool reviveUsed = false;
  double elapsed = 0;

  void start() {
    state = OrbitState.playing;
    score = 0;
    level = 1;
    ring = 0;
    reviveUsed = false;
    elapsed = 0;
  }

  bool land() {
    if (state != OrbitState.playing || ring == GameRules.radii.length - 1) {
      return false;
    }
    ring++;
    score++;
    return true;
  }

  bool nextSector() {
    if (state != OrbitState.playing || ring != GameRules.radii.length - 1) {
      return false;
    }
    ring = 0;
    level++;
    return true;
  }

  bool die() {
    if (state != OrbitState.playing) return false;
    state = OrbitState.gameOver;
    return true;
  }

  bool revive({required bool earned}) {
    if (!earned || reviveUsed || state != OrbitState.gameOver) return false;
    reviveUsed = true;
    state = OrbitState.playing;
    return true;
  }
}

class AdCadence {
  int deaths = 0;
  void recordDeath() => deaths++;
  bool get due => deaths >= 3;
  void onAdShown() => deaths = 0;
}
