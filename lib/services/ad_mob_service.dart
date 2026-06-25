import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  // Real integration is enabled. Test ad unit IDs are used by default so the
  // app can be safely tested before your real AdMob account/ad units are ready.
  // Replace these with your own AdMob IDs before release/monetization.
  static const bool adsEnabled = true;

  static const String androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  // TODO: Replace with your real AdMob banner unit when ready.
  static const String androidProductionBannerAdUnitId = '';
  static const String iosProductionBannerAdUnitId = '';

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

  static RequestConfiguration get requestConfiguration => RequestConfiguration(
        testDeviceIds: const <String>[],
      );
}
