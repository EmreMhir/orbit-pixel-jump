import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_config.dart';
import 'core/game_rules.dart';
import 'core/settings_store.dart';
import 'game/orbit_game.dart';
import 'game/ui/overlays.dart';
import 'game/ui/theme.dart';
import 'managers/ad_manager.dart';
import 'managers/audio_manager.dart';
import 'managers/consent_manager.dart';
import 'screens/gdpr_screen.dart';

class OrbitApp extends StatelessWidget {
  const OrbitApp({
    super.key,
    required this.settings,
    this.createAudio,
    this.createConsent,
  });
  final SettingsStore settings;
  final AudioManager Function(SettingsStore)? createAudio;
  final ConsentManager Function(SettingsStore)? createConsent;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.title,
    debugShowCheckedModeBanner: false,
    theme: OrbitTheme.data,
    home: _LaunchGate(
      settings: settings,
      createAudio: createAudio,
      createConsent: createConsent,
    ),
  );
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate({
    required this.settings,
    this.createAudio,
    this.createConsent,
  });
  final SettingsStore settings;
  final AudioManager Function(SettingsStore)? createAudio;
  final ConsentManager Function(SettingsStore)? createConsent;
  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  late final AudioManager _audio;
  late final ConsentManager _consent;
  final _ads = AdManager();
  OrbitGame? _game;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _consent =
        widget.createConsent?.call(widget.settings) ??
        ConsentManager(settings: widget.settings);
    _consent.onFormRequired = () {
      _game?.pauseRun();
      unawaited(_audio.suspend());
    };
    _audio =
        widget.createAudio?.call(widget.settings) ??
        AudioManager(widget.settings);
    if (widget.settings.policyAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
    }
  }

  Future<void> _launch() async {
    if (_starting || _game != null) return;
    setState(() {
      _starting = true;
    });
    try {
      if (!widget.settings.policyAccepted) await widget.settings.acceptPolicy();
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
      rethrow;
    }
    if (!mounted) return;
    setState(() {
      _game = OrbitGame(
        settings: widget.settings,
        audio: _audio,
        ads: _ads,
        consent: _consent,
      );
      _starting = false;
    });
    // Render the menu before touching network/native advertising and audio APIs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prepareAudio());
      unawaited(_prepareAds());
    });
  }

  Future<void> _prepareAudio() async {
    await _audio.initialize();
    if (mounted &&
        !(_game?.userPaused ?? true) &&
        !_ads.fullScreenShowing &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await _audio.resume();
    }
  }

  Future<void> _prepareAds() async {
    await _consent.gather();
    if (!mounted) return;
    await _ads.configure(
      canRequestAds: _consent.canRequestAds,
      audienceEligible: widget.settings.adsEligible,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_game != null) return _GameScreen(game: _game!);
    if (_starting || widget.settings.policyAccepted) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Yörüngeler hazırlanıyor…'),
            ],
          ),
        ),
      );
    }
    return GDPRScreen(onAccepted: _launch);
  }

  @override
  void dispose() {
    _ads.clearAds();
    _consent.dispose();
    _audio.dispose();
    super.dispose();
  }
}

class _GameScreen extends StatefulWidget {
  const _GameScreen({required this.game});
  final OrbitGame game;
  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.game.reducedMotion = true;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.game.ui,
    builder: (context, value, child) => PopScope(
      canPop:
          widget.game.run.state == OrbitState.menu &&
          !widget.game.ads.fullScreenShowing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.game.isPlaying) widget.game.pauseRun();
      },
      child: child!,
    ),
    child: Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.game.jump();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (widget.game.userPaused) {
                widget.game.resumeRun();
              } else {
                widget.game.pauseRun();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GameWidget<OrbitGame>(
            game: widget.game,
            loadingBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Oyun yüklenemedi. Uygulamayı yeniden açın.\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
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
}
