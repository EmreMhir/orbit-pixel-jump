import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:orbit_jump/app.dart';
import 'package:orbit_jump/core/app_config.dart';
import 'package:orbit_jump/core/settings_store.dart';
import 'package:orbit_jump/managers/ad_manager.dart';
import 'package:orbit_jump/managers/consent_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RestrictedConsent implements ConsentInformation {
  ConsentRequestParameters? received;
  bool permitted = true;
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener success,
    OnConsentInfoUpdateFailureListener failure,
  ) {
    received = params;
    success();
  }

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.notRequired;
  @override
  Future<bool> canRequestAds() async => permitted;
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
  Future<SettingsStore> settings(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SettingsStore(await SharedPreferences.getInstance());
  }

  testWidgets(
    'First launch shows privacy only, without age or publisher branding',
    (tester) async {
      final store = await settings({});
      await tester.pumpWidget(OrbitApp(settings: store));
      await tester.pump();
      expect(find.text('Gizlilik metnini oku'), findsOneWidget);
      expect(find.text('Oyuna Başla'), findsOneWidget);
      expect(find.textContaining('yaş'), findsNothing);
      expect(find.textContaining('EMREDEV'), findsNothing);
      expect(find.textContaining('emredev'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Old minor selection no longer hides ads and is removed on policy update',
    () async {
      final store = await settings({
        'audience_version': 1,
        'adult_ads_eligible': false,
        'policy_version': 2,
      });
      expect(store.policyAccepted, isFalse);
      await store.acceptPolicy();
      expect(store.adsEligible, isTrue);
      expect(store.preferences.containsKey('audience_version'), isFalse);
      expect(store.preferences.containsKey('adult_ads_eligible'), isFalse);
    },
  );

  test(
    'Demo ads work without publisher UMP setup, but only after local privacy notice',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = await settings({});
      final consent = ConsentManager(settings: store, testAds: true);
      addTearDown(consent.dispose);
      await consent.gather();
      expect(consent.canRequestAds, isFalse);
      await store.acceptPolicy();
      await consent.gather();
      expect(consent.canRequestAds, isTrue);
      expect(consent.privacyOptionsRequired, isFalse);
    },
  );

  test(
    'Live ads use under-age protection and still obey UMP permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final previous = ConsentInformation.instance;
      final backend = RestrictedConsent();
      ConsentInformation.instance = backend;
      addTearDown(() {
        ConsentInformation.instance = previous;
        debugDefaultTargetPlatformOverride = null;
      });
      final store = await settings({'policy_version': AppConfig.policyVersion});
      final consent = ConsentManager(settings: store, testAds: false);
      addTearDown(consent.dispose);
      await consent.gather();
      expect(backend.received!.tagForUnderAgeOfConsent, isTrue);
      expect(consent.canRequestAds, isTrue);
      backend.permitted = false;
      await consent.gather();
      expect(consent.canRequestAds, isFalse);
      final ads = AdManager.forTesting();
      await ads.configure(
        canRequestAds: consent.canRequestAds,
        audienceEligible: store.adsEligible,
      );
      expect(ads.allowed, isFalse);
      expect(await ads.showRewarded(), isFalse);
      ads.dispose();
    },
  );
}
