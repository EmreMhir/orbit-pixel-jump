import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:orbit_jump/app.dart';
import 'package:orbit_jump/core/app_config.dart';
import 'package:orbit_jump/core/game_rules.dart';
import 'package:orbit_jump/core/settings_store.dart';
import 'package:orbit_jump/game/orbit_game.dart';
import 'package:orbit_jump/managers/ad_manager.dart';
import 'package:orbit_jump/managers/audio_manager.dart';
import 'package:orbit_jump/managers/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SlowAudio extends AudioManager {
  SlowAudio(super.settings) : super(enabled: false);
  final pending = Completer<void>();
  @override
  Future<void> initialize() => pending.future;
}

class SlowConsent extends ConsentManager {
  SlowConsent(SettingsStore settings) : super(settings: settings);
  final pending = Completer<void>();
  @override
  Future<void> gather() => pending.future;
}

class SlowInterstitial extends AdManager {
  SlowInterstitial() : super.forTesting();
  final pending = Completer<bool>();
  @override
  bool get interstitialReady => true;
  @override
  Future<bool> maybeShowInterstitial() => pending.future;
}

class NoConsentResponse implements ConsentInformation {
  VoidCallback? success;
  int statusReads = 0;
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener onSuccess,
    OnConsentInfoUpdateFailureListener onFailure,
  ) {
    success = onSuccess;
  }

  @override
  Future<ConsentStatus> getConsentStatus() async {
    statusReads++;
    return ConsentStatus.notRequired;
  }

  @override
  Future<bool> canRequestAds() async => true;
  @override
  Future<bool> isConsentFormAvailable() async => false;
  @override
  Future<void> reset() async {}
  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.notRequired;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SettingsStore> settings() async {
    SharedPreferences.setMockInitialValues({
      'policy_version': AppConfig.policyVersion,
      'audience_version': 1,
      'adult_ads_eligible': true,
    });
    return SettingsStore(await SharedPreferences.getInstance());
  }

  testWidgets('Menu and play work while consent and audio never finish', (
    tester,
  ) async {
    final store = await settings();
    final audio = SlowAudio(store);
    final consent = SlowConsent(store);
    await tester.pumpWidget(
      OrbitApp(
        settings: store,
        createAudio: (_) => audio,
        createConsent: (_) => consent,
      ),
    );
    for (var i = 0; i < 30 && find.text('OYNA').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('OYNA'), findsOneWidget);
    expect(audio.pending.isCompleted, isFalse);
    expect(consent.pending.isCompleted, isFalse);
    await tester.tap(find.text('OYNA'));
    await tester.pump();
    final game = tester
        .widget<GameWidget<OrbitGame>>(find.byType(GameWidget<OrbitGame>))
        .game!;
    expect(game.run.state, OrbitState.playing);
    await tester.pumpWidget(const SizedBox());
    audio.pending.complete();
    consent.pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu is visible before an interstitial dismissal callback', (
    tester,
  ) async {
    final store = await settings();
    final ads = SlowInterstitial();
    final audio = AudioManager(store, enabled: false);
    final consent = ConsentManager(settings: store, testAds: false);
    final game = OrbitGame(
      settings: store,
      audio: audio,
      ads: ads,
      consent: consent,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<OrbitGame>(
          game: game,
          overlayBuilderMap: {
            'Menu': (_, _) => const Text('Menu ready'),
            'Hud': (_, _) => const SizedBox(),
            'GameOver': (_, _) => const SizedBox(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.pump();
    game.startRun();
    game.die();
    final transition = game.returnToMenu();
    await tester.pump();
    expect(game.run.state, OrbitState.menu);
    expect(find.text('Menu ready'), findsOneWidget);
    expect(ads.pending.isCompleted, isFalse);
    ads.pending.complete(false);
    await transition;
    await tester.pumpWidget(const SizedBox());
    audio.dispose();
    consent.dispose();
    ads.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Consent network timeout fails closed; late response cannot show a form',
    (tester) async {
      final store = await settings();
      final previous = ConsentInformation.instance;
      final backend = NoConsentResponse();
      ConsentInformation.instance = backend;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        ConsentInformation.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      final consent = ConsentManager(settings: store, testAds: false);
      final pending = consent.gather();
      await tester.pump(const Duration(seconds: 9));
      await pending;
      expect(consent.canRequestAds, isFalse);
      expect(consent.errorMessage, contains('TimeoutException'));
      backend.success?.call();
      await tester.pump();
      expect(backend.statusReads, 0);
      consent.dispose();
      ConsentInformation.instance = previous;
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
