import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class SettingsStore {
  SettingsStore(this.preferences);
  final SharedPreferences preferences;
  int get highScore => preferences.getInt('high_score') ?? 0;
  bool get muted => preferences.getBool('muted') ?? false;
  // No age is requested or inferred. All requests receive child protections.
  bool get adsEligible => policyAccepted;

  bool get policyAccepted =>
      preferences.getInt('policy_version') == AppConfig.policyVersion;

  Future<void> acceptPolicy() async {
    if (!await preferences.setInt('policy_version', AppConfig.policyVersion)) {
      throw StateError('Onay bu cihaza kaydedilemedi. Lütfen yeniden deneyin.');
    }
    await preferences.remove('audience_version');
    await preferences.remove('adult_ads_eligible');
  }

  Future<void> saveHighScore(int value) async {
    if (value <= highScore) return;
    try {
      await preferences.setInt('high_score', value);
    } catch (error) {
      debugPrint('Score persistence failed: $error');
    }
  }

  Future<void> setMuted(bool value) async {
    await preferences.setBool('muted', value);
  }
}
