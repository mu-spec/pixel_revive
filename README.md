# PixelRevive - Version 1

A real, functional Flutter app for **AI Photo Restore & Enhancement**.  
This is **Version 1** and uses **on-device image processing** so it works without any paid API. When you later connect a paid AI backend, the feature screens and state management are already in place.

## What Version 1 already does (real pixels, not demo)

- **One-Tap Auto Enhance** — contrast, brightness, saturation, sharpening
- **HD Upscale** — 2x / 4x bicubic upscale + sharpening
- **Face Enhance** — ML Kit face detection + local smoothing/sharpening on face regions
- **Denoise** — real noise reduction with Gaussian blur + sharpening
- **Unblur** — unsharp mask filter
- **Colorize B&W** — warm colorization filter for black & white photos
- **Old Photo Restore** — removes sepia cast, fixes faded colors, reduces noise
- **Cartoon Effect** — color quantization + edge sharpening
- **Background Blur** — ML Kit face detection + background Gaussian blur
- **Before/After slider** — real comparison of original vs processed image
- **Save / Share** — writes processed image to gallery and system share sheet
- **Free vs Premium** — 3 free exports/day with watermark, premium removes limits (local toggle for testing)

## Project setup

### 1. Prerequisites

- Flutter SDK 3.22+ (stable channel)
- Android Studio or VS Code with Flutter extension
- Android SDK 21+ (compileSdk 34)
- JDK 17

### 2. Clone & run

```bash
cd pixel_revive
flutter pub get
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
flutter run
```

### 3. Build release APK locally

Create a signing keystore if you don't have one:

```bash
keytool -genkey -v -keystore release.keystore -alias pixelrevive -keyalg RSA -keysize 2048 -validity 10000
```

Set environment variables in your terminal:

```bash
export CM_KEYSTORE_PATH=release.keystore
export CM_KEYSTORE_PASSWORD=your_password
export CM_KEY_ALIAS=pixelrevive
export CM_KEY_PASSWORD=your_password
```

Then build:

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Codemagic setup (automatic APK builds)

1. Push this project to GitHub / GitLab / Bitbucket.
2. In Codemagic, create an app and connect the repository.
3. Upload your `release.keystore` in **Build → Android keystore** (or as a Secure File).
4. Add these environment variables in **Build → Environment variables**:
   - `CM_KEYSTORE_PATH` — path of the uploaded keystore secure file
   - `CM_KEYSTORE_PASSWORD` — encrypted
   - `CM_KEY_ALIAS` — encrypted
   - `CM_KEY_PASSWORD` — encrypted
5. Replace `your-email@example.com` in `codemagic.yaml` with your email.
6. Trigger a build. Codemagic will produce the release APK as an artifact.

## Next version roadmap (when you get the API)

1. Replace local filters with **Replicate / FAL AI / Clipdrop** APIs for:
   - GFPGAN face restoration
   - Real-ESRGAN super-resolution
   - CodeFormer
   - true AI colorization
2. Add **Google Mobile Ads** and real **In-App Purchase** products.
3. Add **batch processing** and **AI video enhance**.
4. Add **cloud credits / subscription backend**.

## File structure

```
lib/
  constants/        App colors, strings, feature list
  models/           Data models
  providers/        AppProvider (state management)
  services/         ImageProcessor, StorageService
  screens/          Home, Editor, Result, Premium, Splash
  widgets/          UI components
android/
  app/build.gradle  Release signing via env variables
  app/src/main/
    AndroidManifest.xml
    kotlin/com/app/revivememories/MainActivity.kt
codemagic.yaml      CI/CD workflow
```

## Notes

- All image processing happens locally using the `image` package. Results are real but not as powerful as cloud AI models.
- ML Kit face detection downloads a model on first use; make sure the device has an internet connection for that first download.
- The `in_app_purchase` and `google_mobile_ads` packages are already wired in for the next version.
