/// =============================================
/// CLOUD API CONFIGURATION
/// =============================================
///
/// SECURITY IMPORTANT:
/// Do NOT hardcode real Replicate/Fal.ai API keys inside Flutter code.
/// Anything inside Flutter code is compiled into the APK and can be extracted.
///
/// Safe production flow:
/// Flutter App → Vercel Backend Proxy → Replicate/Fal.ai API
///
/// Your real Replicate API key is stored safely in Vercel Environment Variables:
/// REPLICATE_API_TOKEN
///
/// The Flutter app only stores the public backend URL.
/// =============================================

class CloudApiConfig {
  // ── SECURE VERCEL BACKEND PROXY ────────────────────
  // This is your live Vercel backend URL.
  // Do NOT add /health or /enhance at the end.
  static const String backendBaseUrl = 'https://pixel-reviveapp.vercel.app';

  // Optional light anti-abuse header.
  // Keep empty unless you also set CLIENT_SHARED_SECRET in Vercel.
  static const String backendClientSecret = '';

  // ── DIRECT API TOKENS — KEEP EMPTY IN FLUTTER ──────
  // Do NOT put real Replicate/Fal.ai keys here.
  // API keys must stay only in Vercel Environment Variables.
  static const String replicateToken = '';
  static const String falToken = '';

  // ── WHICH PROVIDER TO USE THROUGH BACKEND ──────────
  // true  = Replicate
  // false = Fal.ai
 static const bool useReplicate = false;

  // ── CLOUD AI POLICY ────────────────────────────────
  // false = OPTION B (matches PRD free tier): free users get a limited number
  //         of real cloud AI runs per day; premium users get unlimited.
  // true  = OPTION A: cloud AI is premium-only (free users get local filters).
  static const bool cloudAiPremiumOnly = false;

  // ── DAILY CLOUD AI LIMIT PER FREE USER ─────────────
  // Used when cloudAiPremiumOnly = false. After this many cloud runs in a day,
  // free users automatically fall back to on-device processing.
  // Cost note: ~$0.002–0.005 per fal.ai run, so 1/day ≈ $0.15/month per
  // active daily free user. Lower this number to control cloud spend.
 static const int freeDailyCloudLimit = 1;

  static String get normalizedBackendBaseUrl =>
      backendBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get useBackendProxy => normalizedBackendBaseUrl.isNotEmpty;

  static Uri get backendEnhanceUri =>
      Uri.parse('$normalizedBackendBaseUrl/enhance');

  static Uri get backendHealthUri =>
      Uri.parse('$normalizedBackendBaseUrl/health');

  static String get activeProviderName => useReplicate ? 'replicate' : 'fal';

  static String get activeProviderLabel => useReplicate ? 'Replicate' : 'Fal.ai';

  // ── HELPER: Is Cloud AI available? ─────────────────
  static bool get isCloudAvailable {
    if (useBackendProxy) return true;
    if (useReplicate) { return replicateToken.isNotEmpty; } else { return falToken.isNotEmpty; }
  }

  // ── HELPER: Get direct token fallback ──────────────
  // This should stay empty in production when backend proxy is used.
  static String get activeToken {
    if (useReplicate) { return replicateToken; } else { return falToken; }
  }
}