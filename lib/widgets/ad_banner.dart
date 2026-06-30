import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/services/ad_mob_service.dart';
import 'package:pixel_revive/services/ump_consent_service.dart';

class AdBanner extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  /// Hide the banner while AI/photo processing is running.
  /// This keeps ads away from loading/progress states and prevents accidental taps.
  final bool hideWhileProcessing;

  /// Hide the banner on very small screens where it may sit too close to buttons.
  final bool hideOnSmallScreens;

  /// Minimum screen height required to show a banner safely.
  final double minScreenHeight;

  const AdBanner({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    this.hideWhileProcessing = true,
    this.hideOnSmallScreens = true,
    this.minScreenHeight = 640,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdMobService.adsEnabled || !UmpConsentService.canRequestAds) return;

    final ad = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  bool _shouldHideBanner(BuildContext context, AppProvider provider) {
    // 1) Never show ads to premium users.
    if (provider.isPremium) return true;

    // 2) Hide when ads are disabled globally or UMP consent is not ready.
    if (!AdMobService.adsEnabled || !UmpConsentService.canRequestAds) return true;

    // 3) Hide while the app is processing/enhancing a photo.
    if (widget.hideWhileProcessing && provider.isProcessing) return true;

    // 4) Hide on small screens where the banner can be too close to action buttons.
    if (widget.hideOnSmallScreens) {
      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final screenWidth = mediaQuery.size.width;
      final safeWidthForBanner = screenWidth >= (AdSize.banner.width + 24);
      final safeHeightForBanner = screenHeight >= widget.minScreenHeight;

      if (!safeWidthForBanner || !safeHeightForBanner) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Banner ads are only inserted in safe screens: AI Lab, Editor, and Result.
    // They are not used on splash, onboarding, language, premium, dialogs,
    // camera/photo picker screens, or purchase screens.
    if (_shouldHideBanner(context, provider)) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: EdgeInsets.zero,
      child: Container(
        alignment: Alignment.center,
        margin: widget.margin,
        width: double.infinity,
        height: _bannerAd!.size.height.toDouble(),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
