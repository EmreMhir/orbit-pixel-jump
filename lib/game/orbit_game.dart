import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../core/game_rules.dart';
import '../core/settings_store.dart';
import '../managers/audio_manager.dart';
import '../managers/ad_manager.dart';
import '../managers/consent_manager.dart';
import 'components/obstacle.dart';
import 'components/orbit_scene.dart';
import 'components/particle_manager.dart';
import 'components/pixel_sprites.dart';
import 'components/player.dart';

// TapDetector is retained because it is explicitly required by this project.
// ignore: deprecated_member_use
class OrbitGame extends FlameGame with HasCollisionDetection, TapDetector {
  OrbitGame({
    required this.settings,
    required this.audio,
    required this.ads,
    required this.consent,
    math.Random? random,
  }) : random = random ?? math.Random(),
       super(
         camera: CameraComponent.withFixedResolution(width: 400, height: 800),
       );
  final SettingsStore settings;
  final AudioManager audio;
  final AdManager ads;
  final ConsentManager consent;
  final math.Random random;
  final run = RunProgress();
  final ui = ValueNotifier<int>(0);
  late Player player;
  late Sprite _meteorSprite;
  late Sprite _playerSprite;
  final List<Obstacle> meteors = [];
  bool gameReady = false;
  bool userPaused = false;
  bool reducedMotion = false;
  bool _leaving = false;
  double _gameOverDelay = 0;
  double _sectorDelay = 0;
  int best = 0;
  bool get isPlaying => run.state == OrbitState.playing && !userPaused;
  double get speed => GameRules.speed(run.level, run.elapsed);

  @override
  Color backgroundColor() => const Color(0xff070d20);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2(200, 400);
    _playerSprite = await PixelSprites.create(player: true);
    _meteorSprite = await PixelSprites.create(player: false);
    best = settings.highScore;
    await world.add(OrbitScene());
    player = Player(_playerSprite);
    await world.add(player);
    _spawnMeteors();
    gameReady = true;
    overlays.add('Menu');
  }

  void refreshUi() => ui.value++;

  void _spawnMeteors() {
    for (final meteor in meteors) {
      meteor.removeFromParent();
    }
    meteors.clear();
    for (var ring = 1; ring < GameRules.radii.length; ring++) {
      final count = GameRules.obstacleCount(run.level, ring);
      final offset = random.nextDouble() * math.pi * 2;
      for (var i = 0; i < count; i++) {
        final obstacle = Obstacle(
          sprite: _meteorSprite,
          ring: ring,
          orbitAngle: offset + i * math.pi * 2 / count,
          angularSpeed:
              (0.30 + random.nextDouble() * 0.38) *
              (random.nextBool() ? 1 : -1),
        );
        meteors.add(obstacle);
        world.add(obstacle);
      }
    }
  }

  void startRun() {
    if (!gameReady || _leaving) return;
    run.start();
    userPaused = false;
    _gameOverDelay = _sectorDelay = 0;
    player.orbitAngle = -math.pi / 2;
    player.reset(ring: 0);
    _spawnMeteors();
    overlays.remove('Menu');
    overlays.remove('GameOver');
    overlays.remove('Pause');
    overlays.add('Hud');
    unawaited(audio.resume());
    unawaited(audio.play('button'));
    ads.setGameplayActive(true);
    refreshUi();
  }

  @override
  void onTapDown(TapDownInfo info) => jump();

  void jump() {
    if (!isPlaying || player.jumping || _sectorDelay > 0 || run.ring >= 4) {
      return;
    }
    player.jumpTo(run.ring + 1);
    unawaited(audio.play('jump'));
  }

  void onLanding() {
    if (!run.land()) return;
    if (run.score > best) {
      best = run.score;
      unawaited(settings.saveHighScore(best));
    }
    if (run.ring == 4) _sectorDelay = 0.30;
    refreshUi();
  }

  void die() {
    if (!isPlaying || !player.alive || !run.die()) return;
    player.alive = false;
    ads.setGameplayActive(false);
    ads.cadence.recordDeath();
    _gameOverDelay = 0.7;
    _sectorDelay = 0;
    ParticleManager.explode(this, player.position);
    unawaited(audio.play('explosion'));
    refreshUi();
  }

  bool revive({required bool earned}) {
    if (!run.revive(earned: earned)) return false;
    ads.setGameplayActive(true);
    _gameOverDelay = 0;
    player.reset(ring: run.ring, shield: GameRules.reviveShield);
    // Outer-ring deaths continue into the next sector after the shielded landing.
    if (run.ring == 4) _sectorDelay = 0.30;
    overlays.remove('GameOver');
    overlays.add('Hud');
    refreshUi();
    return true;
  }

  Future<void> returnToMenu() async {
    if (_leaving) return;
    _leaving = true;
    run.state = OrbitState.menu;
    run.ring = 0;
    userPaused = false;
    _gameOverDelay = _sectorDelay = 0;
    player.reset(ring: 0);
    overlays.remove('GameOver');
    overlays.remove('Hud');
    overlays.remove('Pause');
    overlays.add('Menu');
    ads.setGameplayActive(false);
    refreshUi();
    // Paint the destination first. A native ad callback must not hold Game Over.
    if (!ads.interstitialReady) {
      _leaving = false;
      unawaited(audio.resume());
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!isMounted) {
      _leaving = false;
      return;
    }
    unawaited(audio.suspend());
    try {
      await ads.maybeShowInterstitial();
    } finally {
      _leaving = false;
      if (isMounted) {
        unawaited(audio.resume());
        refreshUi();
      }
    }
  }

  void pauseRun() {
    if (!isPlaying) return;
    userPaused = true;
    ads.setGameplayActive(false);
    overlays.add('Pause');
    unawaited(audio.suspend());
    refreshUi();
  }

  void resumeRun() {
    if (!userPaused) return;
    userPaused = false;
    ads.setGameplayActive(true);
    overlays.remove('Pause');
    unawaited(audio.resume());
    refreshUi();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      pauseRun();
      unawaited(audio.suspend());
    }
    super.lifecycleStateChange(state);
    if (state == AppLifecycleState.resumed &&
        !userPaused &&
        !ads.fullScreenShowing) {
      unawaited(audio.resume());
    }
  }

  @override
  void update(double dt) {
    if (!gameReady) {
      super.update(dt);
      return;
    }
    if (userPaused) return;
    if (!isPlaying && _gameOverDelay <= 0) {
      super.update(dt.clamp(0.0, GameRules.maxFrameTime));
      return;
    }
    var remaining = dt.clamp(0.0, GameRules.maxFrameTime);
    while (remaining > 0.000001) {
      final step = math.min(remaining, GameRules.physicsStep);
      if (isPlaying) {
        run.elapsed += step;
        if (_sectorDelay > 0) {
          _sectorDelay -= step;
          if (_sectorDelay <= 0 && run.nextSector()) {
            player.reset(ring: 0, shield: 0.4);
            _spawnMeteors();
            unawaited(audio.play('sector'));
            refreshUi();
          }
        }
      }
      super.update(step);
      if (_gameOverDelay > 0) {
        _gameOverDelay -= step;
        if (_gameOverDelay <= 0) {
          overlays.remove('Hud');
          overlays.add('GameOver');
        }
      }
      remaining -= step;
    }
  }

  @override
  void onRemove() {
    ads.clearAds();
    ads.setGameplayActive(false);
    ui.dispose();
    if (gameReady) {
      _playerSprite.image.dispose();
      _meteorSprite.image.dispose();
    }
    super.onRemove();
  }
}
