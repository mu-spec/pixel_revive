# PixelRevive — PRD vs Actual Code Audit

**Date:** 2026-06-26  
**Scope:** Comparison of the PRD (`app idea.pdf`) against the real implementation in `pixel_revive/`.

---

## ⚠️ The single most important finding (read this first)

The PRD describes an **AI** photo app. The code's `v1` runs almost entirely on **traditional, hand-written image filters** (bilateral blur, unsharp mask, histogram stretch, color tint, color quantization) running on the CPU via the `image` package — **not AI models**. The app's own README admits this honestly ("on-device image processing... not as powerful as cloud AI models"), but several features are **marketed to users as AI** when they are not.

- The **real AI (Replicate / Fal.ai: GFPGAN, Real-ESRGAN, CodeFormer, DDColor)** is fully built but lives behind a **cloud toggle** that is **off by default for free users** (`cloudAiPremiumOnly = true`). If the Vercel backend has no `REPLICATE_API_TOKEN`, the cloud path silently fails and falls back to the basic local filters.
- So: **free users (the default) never experience the AI the PRD promises.** They get classic filters branded as "AI."

---

## ✅ FULLY IMPLEMENTED (matches PRD)

| PRD Feature | Status | Notes |
|---|---|---|
| **One-Tap Auto Enhance** (the "most important" feature) | ✅ Real | `autoEnhance`: contrast/brightness/saturation + sharpen + light denoise. Genuinely works. |
| **Denoise** (remove grain) | ✅ Real | Bilateral filter (`_advancedDenoise`) + unsharp mask. Honest implementation. |
| **Unblur** (remove soft/motion blur) | ✅ Real | Multi-pass unsharp masking + contrast. Honest (within limits of filter-based). |
| **Face Enhance** (sharpen eyes/mouth, smooth skin) | ✅ Real, good | Uses **Google ML Kit face detection** with landmarks → local skin smoothing + detail sharpening on eyes/mouth. This is the best-implemented feature. (Cloud: GFPGAN/CodeFormer.) |
| **Before/After Slider** ("VERY important for marketing") | ✅ Real, polished | Draggable slider, clip mask, pinch-zoom, labels. Good quality. |
| **Old Photo Restore — color/contrast part** | ✅ Real | Histogram white-balance + contrast stretch + denoise + sharpen. See gaps below for "scratches". |
| **Free tier limits + watermark** | ✅ Real | 3 free exports/day enforced; `applyWatermark` adds corner text. |
| **Save to gallery / Share sheet** | ✅ Real | `gal` (real gallery save) + `share_plus`. |
| **Flutter frontend + clean UI** | ✅ Real | Polished dark UI, onboarding, multi-language (en/es/fr/ur/ar/de). |
| **Cloud AI infrastructure (Replicate + Fal.ai)** | ✅ Built | Vercel backend proxy (`server.js`) with per-feature model routing, polling, security headers. Architecture is correct and secure. |
| **Batch processing** | ✅ Built | `BatchProcessScreen` + `processBatch`. (Premium-only for cloud.) |
| **Localization, onboarding, splash, launcher icons, CI/CD (Codemagic)** | ✅ Done | Beyond PRD scope, nicely done. |

---

## 🟡 HALF / PARTIALLY IMPLEMENTED (works but doesn't fully match the PRD promise)

| PRD Feature | What's there | What's missing / misleading |
|---|---|---|
| **HD/4K Upscale** (true super-resolution) | `upscale()` = bicubic resize + sharpen, 2x/4x, capped at `2400×scale`. | **Not AI super-resolution.** It's classic resampling. Cloud path uses Real-ESRGAN (real AI) but is premium-gated. |
| **Colorize B&W** (the "very viral" feature) | `colorize()` applies a **luminance-based warm tint** (dark→bluish, mid→warm, bright→neutral). | **Not real colorization.** It's a fixed heuristic tint. The code's own strings admit: *"Dedicated historical AI colorization can be added later."* Cloud DDColor is the real version (premium-gated). |
| **Cartoon / Anime Convert** | `cartoonEffect()` = 16-color quantization + edge tracing. | Decent **cartoon** filter, but **not anime/stylization** (no neural style transfer). |
| **Background Cleanup** (remove objects) | `backgroundCleanup()` just **darkens the corners/vignette** (center-focus). | **Does NOT remove objects** or clean backgrounds. Cloud `remove-bg` does real BG removal (premium-gated). |
| **Background Blur ("keep face sharp")** | `backgroundBlur()` blurs from **geometric image center outward**. | 🐞 **Bug / false claim:** it does **not** use the detected face. The UI strings say *"Blur background, keep face sharp,"* but the code ignores faces entirely and uses center-based radial blur. If the subject is off-center, their face gets blurred. |
| **Ads (monetization)** | `AdBanner` + `google_mobile_ads` wired in. | Uses **Google test ad unit IDs only** — no production ad units. Real revenue not possible yet. Premium-hide-ad logic is not clearly enforced everywhere. |
| **"Faster AI processing" (premium)** | Listed as a premium benefit. | ❌ Not implemented — labeled *"Coming soon"* in strings. |

---

## ❌ NOT IMPLEMENTED (in PRD, missing from code)

| PRD Feature | Status |
|---|---|
| **Real In-App Purchase / Subscriptions** | ❌ **Completely absent.** No `in_app_purchase` package in `pubspec.yaml` and **zero references** in code. Premium is a **local `SharedPreferences` toggle** — tapping "Unlock" just flips a boolean. The app even says: *"Real Google Play / Apple App Store Billing will be connected in next step. Clicking the unlock button simulates billing."* No real money can be collected. |
| **Old Photo Restore — scratch & physical-damage removal** | ❌ Not done locally. The restore function fixes color/fade only. (Cloud `microsoft/bringing-old-photos-back-to-life` with `with_scratch:true` can do it — but premium-gated.) |
| **AI Portrait Improve** (as a distinct feature) | ❌ No separate feature; partially absorbed into Face Enhance skin smoothing. |
| **Clipdrop / Stability AI providers** | ❌ Only Replicate + Fal.ai are implemented (PRD listed 4 API options). |
| **"Remove motion blur" as a dedicated tool** | ❌ Folded into the generic Unblur filter; no motion-blur-specific deconvolution. |
| **Cloud AI for free users (even limited)** | ❌ Gated to premium by default (`cloudAiPremiumOnly = true`). The PRD implies free users get limited-but-real AI; in practice free users get only filters. |

---

## 🧪 Things that *look* done but have a hidden dependency

1. **Cloud AI actually working = depends on the Vercel secret key.**  
   `cloud_api_config.dart` points to `https://pixel-reviveapp.vercel.app`, and `backend/.env.example` shows `REPLICATE_API_TOKEN=` **empty**. If that token is not set in Vercel's dashboard, **every cloud enhancement silently fails** and the app falls back to local filters without telling the user it's not really AI. → **Verify the live `/health` endpoint reports `replicateConfigured: true`.**

2. **GPU Shader Service exists but is cosmetic.**  
   `GpuShaderService` (GLSL `.frag`) is only used for fast previews of brightness/contrast/saturation/sharpen — **never** in the main processing pipeline. Don't expect it to speed up the real features.

3. **Processing speed.** PRD stresses "FAST results." Local processing is **pure-Dart per-pixel CPU loops** (e.g. bilateral denoise, face enhance) on `compute()` isolates. On large images this can be slow on mid-range phones — the opposite of "fast."

---

## 📊 Summary scorecard

| Area | Verdict |
|---|---|
| **App skeleton, UI, navigation, polish** | ✅ Strong, production-ish |
| **Classic image filters** (auto/denoise/unblur/face) | ✅ Real & functional |
| **"AI" marketing vs local reality** | 🟡 Misleading — filters sold as AI |
| **Real AI via cloud** | ✅ Built · ⚠️ premium-gated + key must exist |
| **Monetization (ads + IAP)** | ❌ Ads = test IDs only · IAP = **not implemented at all** |
| **PRD "best combo" (restore/face/upscale/colorize/unblur/denoise)** | 🟡 All present as features, but restore-scratch, upscale, colorize are filter-grade, not AI-grade |

### Bottom line
The project is a **solid, well-structured v1 with a real, working app shell and genuinely functional local filters**, plus a **correctly architected cloud-AI backend**. However, it **does not yet deliver the AI experience the PRD sells** to most users, and the two things needed to actually make money — **real In-App Purchases and real ad units — are not implemented.** Treat the current state as a polished demo/prototype, not a monetizable release.
