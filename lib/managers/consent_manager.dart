import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/settings_store.dart';
import '../core/app_config.dart';

class ConsentManager extends ChangeNotifier {
  ConsentManager({required this.settings, this.testAds = AppConfig.testAds});
  final SettingsStore settings;
  final bool testAds;
  VoidCallback? onFormRequired;
  bool _disposed = false;
  Future<void>? _pending;
  bool get supported =>
      settings.adsEligible &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  bool canRequestAds = false;
  bool privacyOptionsRequired = false;
  String? errorMessage;

  Future<void> gather() =>
      _pending ??= _gather().whenComplete(() => _pending = null);

  Future<void> _gather() async {
    if (!supported || _disposed) {
      canRequestAds = false;
      privacyOptionsRequired = false;
      return;
    }
    // Google demo units do not need a publisher's UMP message configuration.
    // Production requests still fail closed unless UMP permits them.
    if (testAds) {
      canRequestAds = true;
      privacyOptionsRequired = false;
      errorMessage = null;
      notifyListeners();
      return;
    }
    final updated = Completer<void>();
    errorMessage = null;
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: true),
        () {
          if (!updated.isCompleted) updated.complete();
        },
        (error) {
          if (!updated.isCompleted) updated.completeError(error);
        },
      );
      // Bound the network phase, never the time a person spends on the form.
      await updated.future.timeout(const Duration(seconds: 8));
      if (_disposed) return;
      final status = await ConsentInformation.instance
          .getConsentStatus()
          .timeout(const Duration(seconds: 3));
      if (_disposed) return;
      if (status == ConsentStatus.required) {
        final loaded = Completer<ConsentForm>();
        var acceptingForm = true;
        ConsentForm.loadConsentForm(
          (form) {
            if (!acceptingForm || _disposed) {
              unawaited(form.dispose());
            } else if (!loaded.isCompleted) {
              loaded.complete(form);
            }
          },
          (error) {
            if (acceptingForm && !loaded.isCompleted) {
              loaded.completeError(error);
            }
          },
        );
        final ConsentForm form;
        try {
          form = await loaded.future.timeout(const Duration(seconds: 8));
        } finally {
          acceptingForm = false;
        }
        try {
          if (_disposed) return;
          onFormRequired?.call();
          final dismissed = Completer<void>();
          form.show((error) {
            if (!_disposed && error != null) errorMessage = error.message;
            if (!dismissed.isCompleted) dismissed.complete();
          });
          await dismissed.future;
        } finally {
          await form.dispose();
        }
      }
      if (!_disposed) await _refresh();
    } catch (error) {
      if (_disposed) return;
      errorMessage = '$error';
      canRequestAds = false;
      notifyListeners();
    }
  }

  Future<void> showPrivacyOptions() async {
    if (!supported ||
        !privacyOptionsRequired ||
        _disposed ||
        _pending != null) {
      return;
    }
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (!_disposed) errorMessage = error?.message;
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    if (!_disposed) await _refresh();
  }

  Future<void> _refresh() async {
    final permitted = await ConsentInformation.instance.canRequestAds().timeout(
      const Duration(seconds: 3),
    );
    final options = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus()
        .timeout(const Duration(seconds: 3));
    if (_disposed) return;
    canRequestAds = permitted;
    privacyOptionsRequired =
        options == PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    onFormRequired = null;
    super.dispose();
  }
}
