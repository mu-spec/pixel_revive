import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Firebase Analytics + Crashlytics wrapper.
///
/// This service is safe to keep in the app even before Firebase is fully
/// configured. If `google-services.json` is missing or Firebase initialization
/// fails, telemetry is disabled and the app continues normally.
class AppTelemetryService {
  static bool _enabled = false;
  static FirebaseAnalytics? _analytics;

  static bool get isEnabled => _enabled;

  static Future<void> init() async {
    if (_enabled) return;
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;

      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      await _analytics!.setAnalyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: true,
          ),
        );
        return true;
      };

      _enabled = true;
      debugPrint('✅ Firebase telemetry initialized');
      await logEvent('app_start');
    } catch (e) {
      _enabled = false;
      _analytics = null;
      debugPrint('⚠️ Firebase telemetry disabled/not configured: $e');
    }
  }

  static Future<void> setUserProperties({
    required bool isPremium,
    required String processingQuality,
    required bool cloudEnabled,
    required String languageCode,
  }) async {
    if (!_enabled || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(name: 'is_premium', value: isPremium ? 'true' : 'false');
      await _analytics!.setUserProperty(name: 'processing_quality', value: processingQuality);
      await _analytics!.setUserProperty(name: 'cloud_enabled', value: cloudEnabled ? 'true' : 'false');
      await _analytics!.setUserProperty(name: 'language', value: languageCode);
    } catch (_) {}
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    if (!_enabled || _analytics == null) return;
    try {
      final sanitized = <String, Object>{};
      parameters.forEach((key, value) {
        if (value == null) return;
        if (value is String) sanitized[key] = value.length > 100 ? value.substring(0, 100) : value;
        if (value is num) sanitized[key] = value;
        if (value is bool) sanitized[key] = value ? 'true' : 'false';
      });
      await _analytics!.logEvent(name: name, parameters: sanitized);
    } catch (e) {
      debugPrint('Telemetry event failed ($name): $e');
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String reason = 'non_fatal',
    Map<String, Object?> information = const <String, Object?>{},
  }) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
        information: information.entries.map((e) => '${e.key}: ${e.value}').toList(),
      );
    } catch (_) {}
  }
}
