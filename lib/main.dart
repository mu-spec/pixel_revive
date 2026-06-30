import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pixel_revive/app.dart';
import 'package:pixel_revive/services/ad_mob_service.dart';
import 'package:pixel_revive/services/ump_consent_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  MobileAds.instance.updateRequestConfiguration(AdMobService.requestConfiguration);

  // Ask for Google UMP ad consent first where it is required.
  // Ads are loaded only after Google says this app can request ads.
  await UmpConsentService.gatherConsent();
  await MobileAds.instance.initialize();

  if (UmpConsentService.canRequestAds) {
    AdMobService.preloadInterstitial();
  }

  runApp(const PixelReviveApp());
}
