abstract final class AppConfig {
  static const title = 'Orbit Pixel Jump';
  static const version = '1.0.3';
  static const publisher = 'emredev';
  static const contact = 'contact@example.com';
  static const policyVersion = 3;
  static const productionAdMobAppId = '';
  static const productionBannerId = '';
  static const productionInterstitialId =
      '';
  static const productionRewardedId = '';
  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
  static const testAds = bool.fromEnvironment('TEST_ADS', defaultValue: true);
  static const bannerId = testAds
      ? 'ca-app-pub-3940256099942544/6300978111'
      : String.fromEnvironment(
          'ADMOB_BANNER_ID',
          defaultValue: productionBannerId,
        );
  static const interstitialId = testAds
      ? 'ca-app-pub-3940256099942544/1033173712'
      : String.fromEnvironment(
          'ADMOB_INTERSTITIAL_ID',
          defaultValue: productionInterstitialId,
        );
  static const rewardedId = testAds
      ? 'ca-app-pub-3940256099942544/5224354917'
      : String.fromEnvironment(
          'ADMOB_REWARDED_ID',
          defaultValue: productionRewardedId,
        );
}
