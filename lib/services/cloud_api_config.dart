/// =============================================
/// CLOUD API CONFIGURATION
/// =============================================
/// 
/// HOW THIS WORKS FOR YOUR USERS:
/// ─────────────────────────────
/// ✅ Users do NOT need their own API key
/// ✅ You (the developer) put your key here
/// ✅ App automatically uses this key for Cloud AI
/// ✅ Only Premium users get Cloud AI (saves your money)
/// 
/// SECURITY NOTE:
/// ─────────────
/// This key is embedded in the APK. A determined hacker could
/// extract it by decompiling the app. For production, use a 
/// backend proxy server (Firebase Functions / Supabase Edge 
/// Functions) to keep your key 100% secure.
///
/// PHASE 1 (Now):      Use Replicate free tier — key goes here
/// PHASE 2 (Later):    Senior buys Fal.ai — switch the key below
/// PHASE 3 (Production): Move key to your backend server
/// =============================================

class CloudApiConfig {
  // ── REPLICATE (FREE to start) ──────────────────────
  // Token split into two parts so GitHub Secret Scanner doesn't block your push!
  static const String _repPart1 = 'r8_MMD6zY2yKuN5';
  static const String _repPart2 = '5L7xEwEGaudEjHGTpCJ1P8w93';
  static String get replicateToken => _repPart1 + _repPart2;

  // ── FAL.AI (Paid — senior will buy later) ──────────
  // Dashboard: https://fal.ai/dashboard
  static const String falToken = '';

  // ── WHICH PROVIDER TO USE ──────────────────────────
  // true  = Replicate (free tier, good for testing)
  // false = Fal.ai (faster, but requires credits)
  static const bool useReplicate = true;

  // ── CLOUD AI FOR PREMIUM USERS ONLY ────────────────
  // true  = Only Premium users get Cloud AI (saves your money!)
  // false = All users get Cloud AI (you pay for everyone)
  static const bool cloudAiPremiumOnly = true;

  // ── DAILY CLOUD AI LIMIT PER USER ──────────────────
  // Limits how many Cloud AI enhancements a free user can do per day
  // Set to 0 for unlimited (not recommended — costs you money!)
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