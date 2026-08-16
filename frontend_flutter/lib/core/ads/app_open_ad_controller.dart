import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../diagnostics/privacy_safe_logger.dart';

/// Owns Signal Path's single cold-start App Open ad for this process.
///
/// Ads are deliberately skipped for onboarding and Pro users. The first two
/// completed launches are also ad-free, following Google's recommendation to
/// let people use an app a few times before showing the first App Open ad.
class AppOpenAdController {
  static const String _launchCountKey = 'admob_app_open_eligible_launches';
  static const int _firstAdLaunch = 3;
  static const Duration _maxCacheDuration = Duration(hours: 4);
  static const String _productionIosAdUnitId =
      'ca-app-pub-2306489052221082/1525572293';
  static const String _testIosAdUnitId =
      'ca-app-pub-3940256099942544/5575463023';

  final PrivacySafeLogger _logger;
  AppOpenAd? _ad;
  DateTime? _loadedAt;
  bool _started = false;
  bool _loading = false;
  bool _showing = false;

  AppOpenAdController({PrivacySafeLogger? logger})
      : _logger = logger ?? PrivacySafeLogger.instance;

  static Future<bool> get isPrivacyOptionsRequired async =>
      !kIsWeb &&
      Platform.isIOS &&
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;

  static Future<FormError?> showPrivacyOptions() {
    final completer = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm(completer.complete);
    return completer.future;
  }

  Future<void> startIfEligible({
    required bool onboardingCompleted,
    required bool isPremium,
  }) async {
    if (_started || !onboardingCompleted || isPremium || !_supportsAds) return;
    _started = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final launchCount = preferences.getInt(_launchCountKey) ?? 0;
      final nextLaunchCount = launchCount + 1;
      await preferences.setInt(_launchCountKey, nextLaunchCount);
      if (nextLaunchCount < _firstAdLaunch) return;

      await _gatherConsentAndLoad();
    } catch (error, stackTrace) {
      _logger.capture(
        error,
        stackTrace,
        operation: 'app_open_ad_start',
      );
    }
  }

  bool get _supportsAds => !kIsWeb && Platform.isIOS && !kDebugMode;

  Future<void> _gatherConsentAndLoad() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            _logger.capture(
              formError,
              StackTrace.current,
              operation: 'admob_consent_form',
            );
          }
          await _initializeAndLoadIfAllowed();
          if (!completer.isCompleted) completer.complete();
        });
      },
      (formError) async {
        _logger.capture(
          formError,
          StackTrace.current,
          operation: 'admob_consent_update',
        );
        await _initializeAndLoadIfAllowed();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<void> _initializeAndLoadIfAllowed() async {
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _loadAd();
  }

  void _loadAd() {
    if (_loading || _showing || _ad != null) return;
    _loading = true;
    AppOpenAd.load(
      adUnitId: kReleaseMode ? _productionIosAdUnitId : _testIosAdUnitId,
      request: const AdRequest(extras: {'rdp': '1'}),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _ad = ad;
          _loadedAt = DateTime.now();
          _showIfAvailable();
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          _logger.capture(
            error,
            StackTrace.current,
            operation: 'app_open_ad_load',
          );
        },
      ),
    );
  }

  void _showIfAvailable() {
    final ad = _ad;
    final loadedAt = _loadedAt;
    if (ad == null || loadedAt == null || _showing) return;
    if (DateTime.now().difference(loadedAt) > _maxCacheDuration) {
      ad.dispose();
      _ad = null;
      _loadedAt = null;
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _showing = true,
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        _showing = false;
        failedAd.dispose();
        _ad = null;
        _loadedAt = null;
        _logger.capture(
          error,
          StackTrace.current,
          operation: 'app_open_ad_show',
        );
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        _showing = false;
        dismissedAd.dispose();
        _ad = null;
        _loadedAt = null;
      },
    );
    ad.show();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
