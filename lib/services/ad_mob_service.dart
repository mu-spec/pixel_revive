import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pixel_revive/services/ump_consent_service.dart';

class AdMobService {
  // Ads are enabled for free users. Premium users are hidden in UI-level checks.
  static const bool adsEnabled = true;

  // ── Google official test IDs kept as safe fallback ──────────────────────
  static const String androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  // ── Your real production AdMob IDs ─────────────────────────────────────
  // Android App ID is set in AndroidManifest.xml:
  // ca-app-pub-7540130362404221~9152303573
  static const String androidProductionBannerAdUnitId =
      'ca-app-pub-7540130362404221/6541462424';
  static const String androidProductionInterstitialAdUnitId =
      'ca-app-pub-7540130362404221/4375149844';

  // iOS is not active for this Android-only build.
  static const String iosProductionBannerAdUnitId = '';
  static const String iosProductionInterstitialAdUnitId = '';

  // Safe frequency cap: show interstitial only after every 3 successful saves.
  // This avoids annoying users and follows a cleaner monetization strategy.
  static const int interstitialSaveFrequency = 3;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialLoading = false;
  static int _successfulSavesSinceInterstitial = 0;

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return androidProductionBannerAdUnitId.isNotEmpty
          ? androidProductionBannerAdUnitId
          : androidTestBannerAdUnitId;
    }
    if (Platform.isIOS) {
      return iosProductionBannerAdUnitId.isNotEmpty
          ? iosProductionBannerAdUnitId
          : iosTestBannerAdUnitId;
    }
    return androidTestBannerAdUnitId;
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return androidProductionInterstitialAdUnitId.isNotEmpty
          ? androidProductionInterstitialAdUnitId
          : androidTestInterstitialAdUnitId;
    }
    if (Platform.isIOS) {
      return iosProductionInterstitialAdUnitId.isNotEmpty
          ? iosProductionInterstitialAdUnitId
          : iosTestInterstitialAdUnitId;
    }
    return androidTestInterstitialAdUnitId;
  }

  static RequestConfiguration get requestConfiguration => RequestConfiguration(
        // Keep empty for production. Add test device IDs here only if you want
        // your physical test phone to receive test ads while using real unit IDs.
        testDeviceIds: const <String>[],
      );

  static void preloadInterstitial() {
    if (!adsEnabled ||
        !UmpConsentService.canRequestAds ||
        _interstitialAd != null ||
        _isInterstitialLoading) {
      return;
    }

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isInterstitialLoading = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          _interstitialAd = null;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Call after a successful save. Shows interstitial only for free users and
  /// only after every [interstitialSaveFrequency] successful saves.
  static void maybeShowInterstitialAfterSave({required bool isPremium}) {
    if (!adsEnabled || isPremium || !UmpConsentService.canRequestAds) return;

    _successfulSavesSinceInterstitial++;
    if (_successfulSavesSinceInterstitial < interstitialSaveFrequency) {
      preloadInterstitial();
      return;
    }

    _successfulSavesSinceInterstitial = 0;

    final ad = _interstitialAd;
    if (ad == null) {
      preloadInterstitial();
      return;
    }

    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('Interstitial failed to show: $error');
        preloadInterstitial();
      },
    );

    ad.show();
  }

  static void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialLoading = false;
  }
}
