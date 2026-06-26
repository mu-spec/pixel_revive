# Testing Guide — Cloud AI Flow (GFPGAN)
### No credit needed yet · test with Face Enhance / Auto Enhance

---

## ✅ What's confirmed working right now

```
Your phone → Vercel backend → Replicate → GFPGAN → real restored image
```
- `face` (GFPGAN) — ✅ proven reliable (returned a real 768×1024 image in ~4s)
- `auto` (GFPGAN) — ✅ uses the same model, will work

## 🟡 What will fall back to LOCAL filters (until you add credit)

These route to **paid models** that currently return 402 (out of credit).
The app handles this gracefully: it runs the local filter instead and shows an
honest *"Cloud AI was unavailable — local processing used"* message.

| Feature | Cloud model | Status now |
|---|---|---|
| upscale | real-esrgan | 🟡 local fallback (402) |
| restore | microsoft old-photos | 🟡 local fallback (402) |
| denoise / unblur | real-esrgan | 🟡 local fallback (402) |
| colorize | ddcolor | 🟡 local fallback (402) |
| bg_cleanup | remove-bg | 🟡 local fallback (402) |

> These will switch to real AI the moment you add $5 credit. No code change.

---

## ▶️ How to test on your device

### 1. Run the app
```bash
cd pixel_revive
flutter pub get          # fetch the new in_app_purchase dependency
flutter run              # on a connected device/emulator
```

### 2. Cloud AI is ON by default (Option B)
With the current config, free users get **3 cloud AI runs/day** automatically.
You don't need to toggle anything.

### 3. Test the WORKING cloud AI flow
1. Tap **Gallery** → pick a photo with a face
2. Tap **Face Enhance**
3. Watch the **processing indicator** — it should say **"Cloud AI"** (blue cloud icon)
4. Drag the **Before/After slider** — you should see a real GFPGAN restoration

### 4. What success looks like
- **Blue "☁️ Cloud AI • Replicate"** badge (not green "Local")
- Result visibly sharper/cleaner than a simple contrast bump
- Takes ~4–13 seconds (cloud latency)

### 5. Test the fallback behavior (optional)
- Pick **Upscale** or **Colorize** → since these models have no credit yet,
  you'll get a **local result** with an **orange "Local Fallback"** badge and an
  honest message. This proves the graceful-degradation path works.

### 6. Test the free-tier limit (optional)
- Run Face Enhance **3 times** as a free user
- The 4th will show **"Daily AI limit reached"** (orange) and use local instead
- This proves the Option B daily-cap logic works

---

## 🔧 If cloud AI shows "Local" instead of "Cloud"

Cloud AI is on by default, but if it's not triggering, check:
- **Premium screen → tap "PixelRevive PRO" 5×** → Developer settings
- Confirm **"Enable Cloud AI"** switch is **ON**
- It should show **"Backend proxy: ✅ Configured securely"**

---

## ➕ When you're ready to enable the other 5 features
1. Go to **replicate.com → Billing → Add credit** ($5 = ~1,500 runs)
2. **No code change, no redeploy** — they instantly start using real AI
3. Tell me **"credit added"** and I'll run the full 7-feature green-light test

---

## Status snapshot (today)
- ✅ GFPGAN (face/auto): real cloud AI, end-to-end
- ✅ All code fixes deployed to Vercel
- ✅ Option B free-tier logic in place
- ⏳ Paid models: waiting on $5 credit to go live
