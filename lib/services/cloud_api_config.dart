/// =============================================
/// CLOUD API CONFIGURATION
/// =============================================
///
/// SECURITY IMPORTANT:
/// Do NOT hardcode real Gemini API keys inside Flutter code.
/// Anything inside Flutter code is compiled into the APK and can be extracted.
///
/// Safe production flow:
/// Flutter App → Backend Proxy → Gemini API
///
/// Your real Gemini API key is stored safely in backend Environment Variables:
/// GEMINI_API_KEY
///
/// The Flutter app only stores the public backend URL.
/// =============================================

class CloudApiConfig {
  // ── SECURE BACKEND PROXY ────────────────────
  // This is your live backend URL. Use your Render/Northflank URL after deployment.
  // Do NOT add /health or /enhance at the end.
  static const String backendBaseUrl = 'https://pixel-reviveapp.vercel.app';

  // Optional light anti-abuse header.
  // Keep empty unless you also set CLIENT_SHARED_SECRET on the backend.
  static const String backendClientSecret = '';

  // ── DIRECT API TOKENS — KEEP EMPTY IN FLUTTER ──────
  // Do NOT put real Gemini keys here.
  // API keys must stay only in backend Environment Variables.
  static const String replicateToken = '';
  static const String geminiToken = '';

  // ── WHICH PROVIDER TO USE THROUGH BACKEND ──────────
  // Gemini is used through backend. This legacy flag is ignored by the Gemini backend.
  static const bool useReplicate = false;

  // ── CLOUD AI POLICY ────────────────────────────────
  // false = OPTION B (matches PRD free tier): free users get a limited number
  //         of real cloud AI runs per day; premium users get unlimited.
  // true  = OPTION A: cloud AI is premium-only (free users get local filters).
  static const bool cloudAiPremiumOnly = false;

  // ── DAILY CLOUD AI LIMIT PER FREE USER ─────────────
  // Used when cloudAiPremiumOnly = false. After this many cloud runs in a day,
  // free users automatically fall back to on-device processing.
  // Lower this number to control Gemini cloud spend during testing.
  static const int freeDailyCloudLimit = 3;

  static String get normalizedBackendBaseUrl =>
      backendBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get useBackendProxy => normalizedBackendBaseUrl.isNotEmpty;

  static Uri get backendEnhanceUri =>
      Uri.parse('$normalizedBackendBaseUrl/api/enhance');

  static Uri get backendHealthUri =>
      Uri.parse('$normalizedBackendBaseUrl/health');

  static String get activeProviderName => 'gemini';

  static String get activeProviderLabel => 'Gemini';

  // ── HELPER: Is Cloud AI available? ─────────────────
  static bool get isCloudAvailable {
    if (useBackendProxy) return true;

    return geminiToken.isNotEmpty;
  }

  // ── HELPER: Get direct token fallback ──────────────
  // This should stay empty in production when backend proxy is used.
  static String get activeToken {
    return geminiToken;
  }
}