import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/app_config.dart';
import '../core/game_rules.dart';

class AdManager extends ChangeNotifier {
  AdManager._();
  @visibleForTesting
  AdManager.forTesting();
  static final AdManager instance = AdManager._();
  factory AdManager() => instance;

  final cadence = AdCadence();
  BannerAd? banner;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _allowed = false;
  bool _initialized = false;
  bool _bannerLoading = false;
  bool _interstitialLoading = false;
  bool _rewardedLoading = false;
  bool fullScreenShowing = false;
  bool bannerReady = false;
  int _generation = 0;
  bool _gameplayActive = false;
  (bool, bool)? _pendingPermission;
  final List<Timer> _preloadTimers = [];
  DateTime? _lastInterstitial;
  DateTime? _rewardedLoadedAt;
  DateTime? _interstitialLoadedAt;
  final Map<String, Timer> _retries = {};
  final Map<String, int> _failures = {};
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get allowed => _allowed && _initialized && supported;
  bool get rewardedReady =>
      allowed &&
      _rewarded != null &&
      !fullScreenShowing &&
      !_expired(_rewardedLoadedAt);
  bool get rewardedLoading => _rewardedLoading;
  bool get interstitialReady =>
      allowed &&
      cadence.due &&
      !fullScreenShowing &&
      _interstitial != null &&
      !_expired(_interstitialLoadedAt) &&
      (_lastInterstitial == null ||
          DateTime.now().difference(_lastInterstitial!) >=
              const Duration(seconds: 90));

  bool _expired(DateTime? loaded) =>
      loaded == null ||
      DateTime.now().difference(loaded) > const Duration(minutes: 50);

  Future<void> configure({
    required bool canRequestAds,
    required bool audienceEligible,
  }) async {
    clearAds();
    if (_gameplayActive) {
      _pendingPermission = (canRequestAds, audienceEligible);
      return;
    }
    _allowed = supported && audienceEligible && canRequestAds;
    if (!_allowed) return;
    final generation = _generation;
    try {
      if (!_initialized) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            maxAdContentRating: MaxAdContentRating.g,
            ageRestrictedTreatment: AgeRestrictedTreatment.child,
          ),
        );
        await MobileAds.instance.initialize().timeout(
          const Duration(seconds: 8),
        );
        _initialized = true;
      }
      if (generation != _generation || !allowed) return;
      preload();
    } catch (error) {
      if (generation != _generation) return;
      _allowed = false;
      debugPrint('Ads initialization failed: $error');
      notifyListeners();
    }
  }

  void preload() {
    if (!allowed || _gameplayActive) return;
    for (final timer in _preloadTimers) {
      timer.cancel();
    }
    _preloadTimers.clear();
    // Spread native/WebView creation across idle menu frames.
    for (final entry in [loadBanner, loadInterstitial, loadRewarded].indexed) {
      _preloadTimers.add(
        Timer(Duration(milliseconds: 250 + entry.$1 * 500), entry.$2),
      );
    }
  }

  void setGameplayActive(bool active) {
    _gameplayActive = active;
    if (active) {
      for (final timer in _preloadTimers) {
        timer.cancel();
      }
      _preloadTimers.clear();
      return;
    }
    final pending = _pendingPermission;
    _pendingPermission = null;
    if (pending != null) {
      unawaited(
        configure(canRequestAds: pending.$1, audienceEligible: pending.$2),
      );
    } else {
      preload();
    }
  }

  void _retry(String key, void Function() load) {
    final failures = (_failures[key] ?? 0) + 1;
    _failures[key] = failures;
    _retries.remove(key)?.cancel();
    if (!allowed || failures > 3) return;
    _retries[key] = Timer(Duration(seconds: 5 * (1 << failures)), () {
      _retries.remove(key);
      load();
    });
  }

  void loadBanner() {
    if (!allowed ||
        _gameplayActive ||
        _bannerLoading ||
        banner != null ||
        AppConfig.bannerId.isEmpty) {
      return;
    }
    _bannerLoading = true;
    final generation = _generation;
    final ad = BannerAd(
      adUnitId: AppConfig.bannerId,
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (generation != _generation || !allowed) {
            ad.dispose();
            return;
          }
          _bannerLoading = false;
          bannerReady = true;
          _failures.remove('banner');
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (generation != _generation) return;
          banner = null;
          bannerReady = false;
          _bannerLoading = false;
          _retry('banner', loadBanner);
          notifyListeners();
        },
      ),
    );
    banner = ad;
    unawaited(ad.load());
  }

  void loadInterstitial() {
    if (_expired(_interstitialLoadedAt)) {
      _interstitial?.dispose();
      _interstitial = null;
    }
    if (!allowed ||
        _gameplayActive ||
        _interstitialLoading ||
        _interstitial != null ||
        AppConfig.interstitialId.isEmpty) {
      return;
    }
    _interstitialLoading = true;
    final generation = _generation;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (generation != _generation || !allowed) {
            ad.dispose();
            return;
          }
          _interstitial = ad;
          _interstitialLoadedAt = DateTime.now();
          _interstitialLoading = false;
          _failures.remove('interstitial');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          if (generation != _generation) return;
          _interstitialLoading = false;
          _retry('interstitial', loadInterstitial);
          notifyListeners();
        },
      ),
    );
  }

  void loadRewarded() {
    if (_expired(_rewardedLoadedAt)) {
      _rewarded?.dispose();
      _rewarded = null;
    }
    if (!allowed ||
        _gameplayActive ||
        _rewardedLoading ||
        _rewarded != null ||
        AppConfig.rewardedId.isEmpty) {
      return;
    }
    _rewardedLoading = true;
    final generation = _generation;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (generation != _generation || !allowed) {
            ad.dispose();
            return;
          }
          _rewarded = ad;
          _rewardedLoadedAt = DateTime.now();
          _rewardedLoading = false;
          _failures.remove('rewarded');
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          if (generation != _generation) return;
          _rewardedLoading = false;
          _retry('rewarded', loadRewarded);
          notifyListeners();
        },
      ),
    );
  }

  Future<bool> showRewarded() async {
    if (!rewardedReady) {
      loadRewarded();
      return false;
    }
    final ad = _rewarded!;
    _rewarded = null;
    fullScreenShowing = true;
    notifyListeners();
    final done = Completer<bool>();
    bool earned = false;
    Timer? showDeadline;
    void finish(bool result) {
      if (done.isCompleted) return;
      showDeadline?.cancel();
      ad.dispose();
      fullScreenShowing = false;
      done.complete(result);
      preload();
      notifyListeners();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) => showDeadline?.cancel(),
      onAdDismissedFullScreenContent: (_) => finish(earned),
      onAdFailedToShowFullScreenContent: (_, error) => finish(false),
    );
    showDeadline = Timer(const Duration(seconds: 3), () => finish(false));
    try {
      unawaited(
        ad
            .show(
              onUserEarnedReward: (_, reward) {
                if (!done.isCompleted) earned = true;
              },
            )
            .catchError((Object error) {
              finish(false);
            }),
      );
    } catch (error) {
      finish(false);
    }
    return done.future;
  }

  Future<bool> maybeShowInterstitial() async {
    final cooledDown =
        _lastInterstitial == null ||
        DateTime.now().difference(_lastInterstitial!) >=
            const Duration(seconds: 90);
    if (!allowed ||
        !cadence.due ||
        !cooledDown ||
        fullScreenShowing ||
        _interstitial == null ||
        _expired(_interstitialLoadedAt)) {
      preload();
      return false;
    }
    final ad = _interstitial!;
    _interstitial = null;
    fullScreenShowing = true;
    final done = Completer<bool>();
    bool shown = false;
    Timer? showDeadline;
    void finish() {
      if (done.isCompleted) return;
      showDeadline?.cancel();
      ad.dispose();
      fullScreenShowing = false;
      done.complete(shown);
      preload();
      notifyListeners();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        if (done.isCompleted) return;
        showDeadline?.cancel();
        shown = true;
        cadence.onAdShown();
        _lastInterstitial = DateTime.now();
      },
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) => finish(),
    );
    notifyListeners();
    showDeadline = Timer(const Duration(seconds: 3), finish);
    try {
      unawaited(
        ad.show().catchError((Object error) {
          finish();
        }),
      );
    } catch (error) {
      finish();
    }
    return done.future;
  }

  void clearAds() {
    _generation++;
    _allowed = false;
    _pendingPermission = null;
    for (final timer in _preloadTimers) {
      timer.cancel();
    }
    _preloadTimers.clear();
    for (final timer in _retries.values) {
      timer.cancel();
    }
    _retries.clear();
    _failures.clear();
    banner?.dispose();
    _interstitial?.dispose();
    _rewarded?.dispose();
    banner = null;
    _interstitial = null;
    _rewarded = null;
    bannerReady = false;
    _bannerLoading = _interstitialLoading = _rewardedLoading = false;
    notifyListeners();
  }
}
