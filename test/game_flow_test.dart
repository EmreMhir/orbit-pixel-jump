import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_jump/core/game_rules.dart';
import 'package:orbit_jump/core/settings_store.dart';
import 'package:orbit_jump/game/orbit_game.dart';
import 'package:orbit_jump/game/ui/overlays.dart';
import 'package:orbit_jump/game/ui/theme.dart';
import 'package:orbit_jump/managers/ad_manager.dart';
import 'package:orbit_jump/managers/audio_manager.dart';
import 'package:orbit_jump/managers/consent_manager.dart';
import 'package:orbit_jump/screens/gdpr_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OrbitGame> mountGame(
  WidgetTester tester, {
  GlobalKey? capture,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsStore(await SharedPreferences.getInstance());
  final game = OrbitGame(
    settings: settings,
    audio: AudioManager(settings, enabled: false),
    ads: AdManager(),
    consent: ConsentManager(settings: settings),
    random: Random(42),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: OrbitTheme.data,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: capture,
          child: GameWidget<OrbitGame>(
            game: game,
            overlayBuilderMap: {
              'Menu': (context, game) => MainMenuOverlay(game: game),
              'Hud': (context, game) => HudOverlay(game: game),
              'GameOver': (context, game) => GameOverOverlay(game: game),
              'Pause': (context, game) => PauseOverlay(game: game),
            },
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await game.toBeLoaded();
  });
  await tester.pump();
  await tester.runAsync(() async {
    await game.ready();
  });
  await tester.pump();
  return game;
}

void step(OrbitGame game, double seconds) {
  for (var i = 0; i < (seconds * 120).ceil(); i++) {
    game.update(1 / 120);
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE')) return;
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('artifacts').createSync(recursive: true);
    File('artifacts/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final size in [
    const Size(375, 667),
    const Size(844, 390),
    const Size(800, 1100),
  ]) {
    testWidgets(
      'all game overlays fit $size with large text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = await mountGame(tester, textScale: 1.7);
        game.reducedMotion = true;
        expect(tester.takeException(), isNull);
        game.startRun();
        await tester.pump();
        expect(tester.takeException(), isNull);
        game.pauseRun();
        await tester.pump();
        expect(tester.takeException(), isNull);
        game.resumeRun();
        game.die();
        step(game, 0.8);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(game.camera.viewfinder.position.x, 200);
        expect(game.camera.viewfinder.position.y, 400);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'actual MoveEffect, pause, hitboxes, delayed game over, earned revive',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mountGame(tester);
      game.startRun();
      await tester.runAsync(() async {
        await game.ready();
      });
      game.player.shieldRemaining = 20;
      game.jump();
      game.jump();
      step(game, 0.06);
      final beforePause = game.player.radius;
      game.pauseRun();
      step(game, 1);
      expect(game.player.radius, closeTo(beforePause, 0.001));
      expect(game.run.score, 0);
      game.resumeRun();
      step(game, 0.20);
      expect(game.run.ring, 1);
      expect(game.run.score, 1);
      expect(game.player.radius, closeTo(84, 0.01));
      game.player.shieldRemaining = 0;
      final meteor = game.meteors.firstWhere((item) => item.ring == 1);
      meteor.orbitAngle = game.player.orbitAngle;
      meteor.syncPosition();
      step(game, 0.02);
      expect(game.run.state, OrbitState.gameOver);
      expect(game.player.alive, isFalse);
      step(game, 0.8);
      expect(game.overlays.isActive('GameOver'), isTrue);
      expect(game.revive(earned: false), isFalse);
      expect(game.revive(earned: true), isTrue);
      expect(game.player.shieldRemaining, greaterThan(2));
      expect(game.run.score, 1);
      game.die();
      expect(game.revive(earned: true), isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sector transition, repeated menu cycles, and screenshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontLoader = FontLoader('PressStart2P')
      ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
    await fontLoader.load();
    await (FontLoader('SpaceGrotesk')
          ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final key = GlobalKey();
    final game = await mountGame(tester, capture: key);
    await capture(tester, key, 'menu');
    game.startRun();
    await tester.runAsync(() async {
      await game.ready();
    });
    game.player.shieldRemaining = 30;
    for (var i = 0; i < 4; i++) {
      game.jump();
      step(game, 0.22);
    }
    expect(game.run.score, 4);
    step(game, 0.4);
    await tester.runAsync(() async {
      await game.ready();
    });
    expect(game.run.level, 2);
    expect(game.run.ring, 0);
    expect(game.player.radius, closeTo(52, 0.1));
    await capture(tester, key, 'playing');
    game.die();
    step(game, 0.8);
    await capture(tester, key, 'game_over');
    await game.returnToMenu();
    game.startRun();
    await tester.runAsync(() async {
      await game.ready();
    });
    expect(game.run.score, 0);
    expect(game.best, 4);
    expect(game.meteors.length, 4);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(375, 667),
    const Size(844, 390),
    const Size(800, 1100),
  ]) {
    testWidgets(
      'consent checkbox and readable layout at $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var accepted = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: OrbitTheme.data,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.7),
              ),
              child: GDPRScreen(
                onAccepted: () async {
                  accepted = true;
                },
              ),
            ),
          ),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(accepted, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
