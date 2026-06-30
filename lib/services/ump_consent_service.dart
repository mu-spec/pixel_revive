import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class UmpConsentService {
  static bool _consentFlowStarted = false;
  static bool _canRequestAds = false;
  static bool _privacyOptionsRequired = false;

  static bool get canRequestAds => _canRequestAds;
  static bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Runs Google's UMP consent flow.
  ///
  /// Important:
  /// - Call this once during app startup before loading ads.
  /// - Google only shows a consent form when it is required for the user.
  /// - If consent is not required in the user's country, this finishes silently.
  static Future<bool> gatherConsent() async {
    if (_consentFlowStarted) return _canRequestAds;
    _consentFlowStarted = true;

    final completer = Completer<bool>();

    final params = ConsentRequestParameters(
      // Production mode. Do not add debug geography/test identifiers here for release.
      consentDebugSettings: null,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) async {
          if (formError != null) {
            debugPrint('UMP consent form error: ${formError.message}');
          }

          await _refreshConsentState();
          if (!completer.isCompleted) {
            completer.complete(_canRequestAds);
          }
        });
      },
      (FormError error) async {
        debugPrint('UMP consent info update error: ${error.message}');
        await _refreshConsentState();
        if (!completer.isCompleted) {
          completer.complete(_canRequestAds);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () async {
        debugPrint('UMP consent flow timed out. Ads will not be requested yet.');
        await _refreshConsentState();
        return _canRequestAds;
      },
    );
  }

  /// Opens Google's privacy options form so users can change their ad consent.
  /// Add this behind a Settings button if Google says privacy options are required.
  static Future<bool> showPrivacyOptionsForm() async {
    final completer = Completer<bool>();

    ConsentForm.showPrivacyOptionsForm((FormError? formError) async {
      if (formError != null) {
        debugPrint('UMP privacy options form error: ${formError.message}');
        await _refreshConsentState();
        completer.complete(false);
        return;
      }

      await _refreshConsentState();
      completer.complete(true);
    });

    return completer.future;
  }

  static Future<void> _refreshConsentState() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();

    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('UMP privacy options status error: $error');
      _privacyOptionsRequired = false;
    }

    debugPrint(
      'UMP consent state: canRequestAds=$_canRequestAds, '
      'privacyOptionsRequired=$_privacyOptionsRequired',
    );
  }
}
