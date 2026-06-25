/// =============================================
/// CLOUD API CONFIGURATION
/// =============================================
///
/// SECURITY IMPORTANT:
/// Do NOT hardcode real Replicate/Fal.ai API keys inside Flutter code.
/// Anything inside Flutter code is compiled into the APK and can be extracted.
///
/// Safe production flow:
/// Flutter App → Backend Proxy → Replicate/Fal.ai API
///
/// Put your real API key only in your backend host environment variables,
/// for example Render/Railway/Firebase secrets.
/// =============================================

class CloudApiConfig {
  // ── SECURE BACKEND PROXY ───────────────────────────
  // After deploying /backend to Vercel, paste the public URL here.
  // Example: https://pixel-revive-backend.vercel.app
  // Leave empty until your backend is deployed; app will use local processing.
  static const String backendBaseUrl = '';

  // Optional light anti-abuse header. Only use if CLIENT_SHARED_SECRET is set
  // on the backend. This is not a replacement for Firebase Auth/App Check.
  static const String backendClientSecret = '';

  // ── DIRECT API TOKENS — KEEP EMPTY IN FLUTTER ──────
  // These are only kept for developer override/testing. Do NOT put real keys
  // here for a production APK.
  static const String replicateToken = '';
  static const String falToken = '';

  // ── WHICH PROVIDER TO USE THROUGH THE BACKEND ──────
  // true  = Replicate
  // false = Fal.ai
  static const bool useReplicate = true;

  // ── CLOUD AI FOR PREMIUM USERS ONLY ────────────────
  static const bool cloudAiPremiumOnly = true;

  // ── DAILY CLOUD AI LIMIT PER USER ──────────────────
  static const int freeDailyCloudLimit = 3;

  static bool get useBackendProxy => backendBaseUrl.trim().isNotEmpty;

  static String get activeProviderName => useReplicate ? 'replicate' : 'fal';

  // ── HELPER: Is Cloud AI available? ─────────────────
  static bool get isCloudAvailable {
    if (useBackendProxy) return true;
    if (useReplicate) {
      return replicateToken.isNotEmpty;
    } else {
      return falToken.isNotEmpty;
    }
  }

  // ── HELPER: Get the active direct token ─────────────
  // This should stay empty in production when using backend proxy.
  static String get activeToken {
    if (useReplicate) {
      return replicateToken;
    } else {
      return falToken;
    }
  }
}
