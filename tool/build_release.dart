import 'dart:io';

import 'package:orbit_jump/core/app_config.dart';

String configuredValue(String key, String fallback) {
  final value = Platform.environment[key]?.trim();
  return value == null || value.isEmpty ? fallback : value;
}

Future<void> main() async {
  try {
    final privacy = configuredValue('ORBIT_PRIVACY_URL', AppConfig.privacyUrl);
    final uri = Uri.tryParse(privacy);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host == 'example.com') {
      throw ArgumentError(
        'ORBIT_PRIVACY_URL must be your published HTTPS policy URL.',
      );
    }
    final appId = configuredValue(
      'ORBIT_ADMOB_APP_ID',
      AppConfig.productionAdMobAppId,
    );
    final banner = configuredValue(
      'ORBIT_ADMOB_BANNER_ID',
      AppConfig.productionBannerId,
    );
    final interstitial = configuredValue(
      'ORBIT_ADMOB_INTERSTITIAL_ID',
      AppConfig.productionInterstitialId,
    );
    final rewarded = configuredValue(
      'ORBIT_ADMOB_REWARDED_ID',
      AppConfig.productionRewardedId,
    );
    final appPattern = RegExp(r'^ca-app-pub-\d{16}~\d{10}$');
    final unitPattern = RegExp(r'^ca-app-pub-\d{16}/\d{10}$');
    if (!appPattern.hasMatch(appId) ||
        ![banner, interstitial, rewarded].every(unitPattern.hasMatch)) {
      throw ArgumentError('AdMob application or ad unit ID format is invalid.');
    }
    if ([
      appId,
      banner,
      interstitial,
      rewarded,
    ].any((id) => id.contains('3940256099942544'))) {
      throw ArgumentError('Store release cannot use Google demo IDs.');
    }
    if (!File('android/key.properties').existsSync()) {
      throw StateError(
        'android/key.properties is required. Read docs/RELEASE_TR.md.',
      );
    }
    final result = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'build',
        'appbundle',
        '--release',
        '--dart-define=TEST_ADS=false',
        '--dart-define=ADMOB_APP_ID=$appId',
        '--dart-define=PRIVACY_URL=$privacy',
        '--dart-define=ADMOB_BANNER_ID=$banner',
        '--dart-define=ADMOB_INTERSTITIAL_ID=$interstitial',
        '--dart-define=ADMOB_REWARDED_ID=$rewarded',
      ],
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await result.exitCode;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
