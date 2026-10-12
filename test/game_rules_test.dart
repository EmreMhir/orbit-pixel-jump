import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_jump/core/game_rules.dart';
import 'package:orbit_jump/core/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('four successful jumps advance a sector and preserve score', () {
    final run = RunProgress()..start();
    expect(run.nextSector(), isFalse);
    for (var i = 0; i < 4; i++) {
      expect(run.land(), isTrue);
    }
    expect(run.score, 4);
    expect(run.land(), isFalse);
    expect(run.nextSector(), isTrue);
    expect((run.level, run.ring, run.score), (2, 0, 4));
  });

  test(
    'one earned revive per round; failed or duplicate callbacks cannot grant it',
    () {
      final run = RunProgress()..start();
      run.land();
      expect(run.die(), isTrue);
      expect(run.die(), isFalse);
      expect(run.revive(earned: false), isFalse);
      expect(run.state, OrbitState.gameOver);
      expect(run.revive(earned: true), isTrue);
      expect((run.score, run.ring), (1, 1));
      run.die();
      expect(run.revive(earned: true), isFalse);
      run.start();
      expect(run.reviveUsed, isFalse);
    },
  );

  test('ad cadence retains due count until an ad actually shows', () {
    final cadence = AdCadence();
    cadence.recordDeath();
    cadence.recordDeath();
    expect(cadence.due, isFalse);
    cadence.recordDeath();
    expect(cadence.due, isTrue);
    cadence.recordDeath();
    expect(cadence.due, isTrue);
    cadence.onAdShown();
    expect(cadence.deaths, 0);
  });

  test('difficulty is monotonic and capped during long runs', () {
    expect(GameRules.speed(2, 10), greaterThan(GameRules.speed(1, 10)));
    expect(GameRules.speed(1, 50), greaterThan(GameRules.speed(1, 10)));
    expect(GameRules.speed(999, 999999), 2.4);
    expect(GameRules.obstacleCount(999, 4), 3);
  });

  test('best score never decreases; sound and policy persist', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore(await SharedPreferences.getInstance());
    expect(settings.policyAccepted, isFalse);
    await settings.saveHighScore(9);
    await settings.saveHighScore(3);
    await settings.setMuted(true);
    await settings.acceptPolicy();
    final reloaded = SettingsStore(await SharedPreferences.getInstance());
    expect(reloaded.highScore, 9);
    expect(reloaded.muted, isTrue);
    expect(reloaded.policyAccepted, isTrue);
  });
}
