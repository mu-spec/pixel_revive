/// =============================================
/// CLOUD API CONFIGURATION
/// =============================================
///
/// SECURITY IMPORTANT:
/// Do NOT hardcode real Replicate/Fal.ai API keys inside Flutter code.
/// Anything inside Flutter code is compiled into the APK and can be extracted.
///
/// For production, use this safe flow:
/// Flutter App → Your Backend/Firebase Function → Replicate/Fal.ai API
///
/// This file intentionally keeps API tokens empty so the APK does not expose
/// your private API key. Cloud AI can be connected later through a backend proxy.
/// =============================================

class CloudApiConfig {
  // ── REPLICATE ─────────────────────────────────────
  // Keep empty in production Flutter app. Use backend proxy instead.
  static const String replicateToken = '';

  // ── FAL.AI ────────────────────────────────────────
  // Keep empty in production Flutter app. Use backend proxy instead.
  static const String falToken = '';

  // ── WHICH PROVIDER TO USE ──────────────────────────
  // true  = Replicate
  // false = Fal.ai
  static const bool useReplicate = true;

  // ── CLOUD AI FOR PREMIUM USERS ONLY ────────────────
  static const bool cloudAiPremiumOnly = true;

  // ── DAILY CLOUD AI LIMIT PER USER ──────────────────
  static const int freeDailyCloudLimit = 3;

  // ── HELPER: Is Cloud AI available? ─────────────────
  static bool get isCloudAvailable {
    if (useReplicate) {
      return replicateToken.isNotEmpty;
    } else {
      return falToken.isNotEmpty;
    }
  }

  // ── HELPER: Get the active token ───────────────────
  static String get activeToken {
    if (useReplicate) {
      return replicateToken;
    } else {
      return falToken;
    }
  }
}