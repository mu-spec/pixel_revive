# How to Make PixelRevive 100% Match Your PRD
### A complete, prioritized, step-by-step roadmap
*(Tailored: Replicate AI · AdMob account ready · no Play Developer account yet)*

---

## 🧭 The reality check — what "100% match" really requires

Your PRD sells an **AI** app. Right now the default experience is **classic filters branded as AI**. To truly match the PRD you must close **5 gaps**:

| # | Gap | Type |
|---|-----|------|
| 1 | Real AI must actually run (not silent fallback to filters) | **Critical** |
| 2 | "Fake" features must become real AI (colorize, upscale, bg cleanup, scratches) | **Critical** |
| 3 | Background Blur bug (ignores faces) | **Bug fix** |
| 4 | Real In-App Purchases (premium is currently a local toggle) | **Monetization** |
| 5 | Real AdMob ad units (currently test IDs) | **Monetization** |

Do them in this order. Each phase ends with a **verify** step so you know it's real, not assumed.

---

## PHASE 0 — Accounts & keys (do this first, ~1 day)

These are prerequisites. No code change makes sense without them.

### 0.1 Replicate account + token
1. Sign up at **replicate.com** → Billing → add a card + **add credit** ($5–10 to start).
2. Go to **Account → API tokens → Create token**. Copy it (starts with `r8_...`).
3. ⚠️ **Never** put this token in Flutter code or commit it. It goes only in Vercel.

### 0.2 Deploy the backend secret key to Vercel
Your backend is already wired (`backend/server.js`). You just need to set the env var:
1. Go to your Vercel project (**pixel-reviveapp**).
2. **Settings → Environment Variables → Add:**
   - Name: `REPLICATE_API_TOKEN`  · Value: your `r8_...` token  · Environment: Production
3. **Redeploy** the Vercel project.
4. **VERIFY:** open `https://pixel-reviveapp.vercel.app/health` in a browser. It MUST return:
   ```json
   { "ok": true, "replicateConfigured": true, ... }
   ```
   If `replicateConfigured` is `false`, the token didn't take. Fix it before moving on — otherwise every "AI" result will silently be a basic filter.

### 0.3 Google Play Developer account (needed only for IAP go-live)
- Cost: **$25 one-time** at **play.google.com/console**.
- You can do all IAP *code* now (Phase 3), but you can't test a real purchase / publish until you have this. Get it in parallel — it takes 1–3 days to verify identity.

---

## PHASE 1 — Make the AI actually real (core of the PRD)

Goal: every enhancement a user sees comes from a real Replicate model, not a filter.

### 1.1 Test cloud AI feature-by-feature
With the token set (Phase 0.2), turn on Cloud AI in the app:
- Premium screen → tap **"PixelRevive PRO" 5×** → Developer settings → **Enable Cloud AI** ON.
- Run each feature and confirm the result is visibly AI-grade (not just a contrast bump).

Checklist (these already have Replicate models in your backend):
- [ ] `restore` → microsoft/bringing-old-photos-back-to-life (fixes **scratches** ✅ + fade)
- [ ] `face` → tencentarc/gfpgan (real face restoration)
- [ ] `upscale` → nightmareai/real-esrgan (real super-resolution)
- [ ] `colorize` → piddnad/ddcolor (real colorization, not a tint)
- [ ] `bg_cleanup` → lucataco/remove-bg (real background removal)
- [ ] `auto` → gfpgan

### 1.2 Fill the missing AI routing (code — see below)
Currently `denoise`, `unblur`, `cartoon`, and `bg` (background blur) have **no dedicated cloud model** and silently fall through to a face model — wrong behavior. Add explicit routing for each (done for you below in code).

### 1.3 Stop the silent lie
If cloud AI ever fails, the app falls back to filters **without telling the user**. Change the messaging so the result screen clearly says *"Cloud AI unavailable — used on-device enhancement"* (your provider already tracks `lastProcessingSource == 'Local Fallback'` — surface it prominently).

---

## PHASE 2 — Fix the broken / fake features (code)

| Feature | Fix |
|---------|-----|
| **Background Blur** 🐞 | Currently blurs from the **image center**, ignoring faces → off-center faces get blurred. **Fix: use ML Kit face detection to keep faces sharp.** *(Implemented in this pass.)* |
| **Colorize** | Local is a tint → must use cloud DDColor (premium). Mark local as "preview only". |
| **Upscale** | Local is bicubic → use cloud Real-ESRGAN (premium). |
| **Background Cleanup** | Local only darkens corners → use cloud remove-bg (premium). |
| **Scratch removal** | Already works in cloud (`restore` uses `with_scratch:true`) — just needs the token. |
| **Cartoon** | Local quantization is an acceptable effect; no must-have AI model. Keep local, label honestly as "Cartoon filter" not "AI Cartoon". |

---

## PHASE 3 — Real monetization (the part that earns money)

### 3.1 Real AdMob ad units (you have the account ✅)
1. **AdMob → Apps → Add app** (you can add it before Play listing using manual flow).
2. **Ad units → Create Banner ad unit** → copy the `ca-app-pub-XXXX/YYYY` ID.
3. Put it in `lib/services/ad_mob_service.dart`:
   ```dart
   static const String androidProductionBannerAdUnitId = 'ca-app-pub-YOUR/UNIT';
   ```
4. **VERIFY:** build & run → confirm a real (non-test) ad loads on a real device. Use your device as a test device in AdMob to avoid policy violations during dev.
5. Make premium users see **no ads**: gate the `AdBanner` widget on `provider.isPremium`.

### 3.2 Real In-App Purchases (code now, live after Play account)
Currently premium = a local `SharedPreferences` boolean. Replace it with real billing:
1. `flutter pub add in_app_purchase`
2. Create products in **Play Console → Monetize → Products** (once you have the account):
   - `premium_weekly` ($2.99), `premium_yearly` ($19.99), `premium_lifetime` ($39.99)
3. Build an `IapService` that: loads products → initiates purchase → listens for `purchaseStatus` → verifies → sets `isPremium` from the verified receipt (not a button).
4. Add **Restore Purchases** (required by Google policy).
5. **Remove** the "Restore Free (For Testing)" and the fake unlock; keep a dev-only override hidden behind the 5-tap menu.
6. **VERIFY:** a real purchase flips premium; reinstall + Restore keeps it.

> This is the biggest remaining build. I can scaffold `IapService` + wire the Premium screen now (it will compile and run in test mode), and you finish it once your Play products exist.

---

## PHASE 4 — Match the PRD monetization model (a cost decision)

The PRD implies **free users get limited real AI** (limited exports + watermark + ads), and **premium gets unlimited/faster AI**. Right now `cloudAiPremiumOnly = true`, meaning **free users never see AI**.

Decision point — choose one:
- **Option A (cost-safe, defensible):** keep AI premium-only. Free = local filters. *Matches "premium = faster AI processing."*
- **Option B (matches PRD's free-tier promise):** set `cloudAiPremiumOnly = false` + `freeDailyCloudLimit = 2–3`. Free users get a few real AI runs/day (subsidized by ads), unlimited via premium. *Higher conversion, but you pay Replicate for free users.*

⚠️ Either way, your backend's rate limiter (`RATE_LIMIT_PER_MINUTE`) is your cost shield — keep it tight.

Tell me which option you want and I'll set the config.

---

## PHASE 5 — Performance & honest labeling (polish)

- **Speed:** local processing uses pure-Dart CPU pixel loops (slow on big images). Options: (a) cap input resolution earlier, (b) move heavy ops to the GPU shader, (c) prefer cloud for large images. The PRD stresses "FAST results" — benchmark on a mid-range phone.
- **"Faster AI processing" premium benefit:** currently a string saying "Coming soon". Either implement priority routing on the backend or remove the claim.
- **Honest labels:** the UI says "AI" everywhere. Either everything the user touches is cloud AI, or relabel local-only features honestly (e.g., "Quick Enhance" vs "AI Enhance").

---

## PHASE 6 — Release to Play Store

1. Generate release keystore (README has the commands) + set in Codemagic.
2. Privacy policy URL (required — app accesses photos, ads, billing).
3. Data safety form in Play Console (photos, ML Kit, ads, billing).
4. Build signed AAB → internal testing → closed → production.
5. Add **AdMob App ID** to `AndroidManifest.xml` (`<meta-data ... android:value="ca-app-pub-YOUR~APPID">`) — required for production ads.

---

## ✅ Master checklist (do top → bottom)

**Accounts**
- [ ] Replicate account + credit + token
- [ ] Token in Vercel env → redeploy → `/health` shows `replicateConfigured: true`
- [ ] Google Play Developer account ($25)

**Code**
- [ ] Background Blur uses face detection ✅ *(done this pass)*
- [ ] Cloud routing for denoise/unblur/cartoon/bg ✅ *(done this pass)*
- [ ] Surface "Local Fallback used" to user when cloud fails
- [ ] Real AdMob banner ad unit + premium hides ads
- [ ] `in_app_purchase` IapService + products + restore
- [ ] Honest feature labels (or all-cloud)
- [ ] Decide free-tier AI policy (Option A or B)

**Release**
- [ ] AdMob App ID in manifest · privacy policy · data safety · signed AAB

---

## 💬 What I need from you next (pick any)
1. **"Set up IAP"** → I'll scaffold the `IapService` + rewire the Premium screen now.
2. **"Option A" or **"Option B"**** → I'll set the free-tier AI policy.
3. **"Wire real AdMob"** → give me your banner unit ID and I'll plug it in.
4. **"Fix more routing"** → I'll complete the remaining model mappings.
