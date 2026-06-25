# PixelRevive Backend Proxy — Vercel Deployment

This backend keeps your Replicate/Fal.ai API keys out of the Flutter APK.

Safe flow:

```text
Flutter App → Vercel Backend Proxy → Replicate/Fal.ai API
```

## Deploy on Vercel Free Plan

1. Push this `backend/` folder to GitHub.
2. Go to https://vercel.com and sign in with GitHub.
3. Click **Add New → Project**.
4. Import your `pixel_revive` GitHub repo.
5. Set **Root Directory** to:

```text
backend
```

6. Add Environment Variables in Vercel:

```text
DEFAULT_AI_PROVIDER=replicate
REPLICATE_API_TOKEN=your_new_replicate_token
MAX_JSON_MB=25
MAX_IMAGE_MB=8
REQUEST_TIMEOUT_MS=55000
```

Do not put your API key in Flutter code or GitHub.

7. Deploy.
8. Open your health URL:

```text
https://your-vercel-project.vercel.app/health
```

You should see:

```json
"replicateConfigured": true
```

## Cloud feature mapping

Current Replicate model mapping:

| App feature | Backend model |
|---|---|
| Auto Enhance | `tencentarc/gfpgan` |
| Face Enhance | `tencentarc/gfpgan` |
| Old Photo Restore | `microsoft/bringing-old-photos-back-to-life` |
| Colorize B&W | `piddnad/ddcolor` |
| HD Upscale | `nightmareai/real-esrgan` |
| BG Cleanup | `lucataco/remove-bg` |

You can override models in Vercel Environment Variables:

```text
REPLICATE_FACE_MODEL=tencentarc/gfpgan
REPLICATE_RESTORE_MODEL=microsoft/bringing-old-photos-back-to-life:c75db81db6cbd809d93cc3b7e7a088a351a3349c9fa02b6d393e35e0d51ba799
REPLICATE_COLORIZE_MODEL=piddnad/ddcolor:ca494ba129e44e45f661d6ece83c4c98a9a7c774309beca01429b58fce8aa695
REPLICATE_COLORIZE_MODEL_SIZE=large
REPLICATE_AUTO_MODEL=tencentarc/gfpgan
REPLICATE_UPSCALE_MODEL=nightmareai/real-esrgan
REPLICATE_BG_CLEANUP_MODEL=lucataco/remove-bg
```

## Connect Flutter app

After Vercel deploys, copy your Vercel URL and put it in:

```text
lib/services/cloud_api_config.dart
```

Example:

```dart
static const String backendBaseUrl = 'https://your-vercel-project.vercel.app';
```

Do not add `/health` or `/enhance` at the end.

## API endpoints

### GET `/health`

Checks backend status.

### POST `/enhance`

Request:

```json
{
  "provider": "replicate",
  "featureId": "face",
  "mimeType": "image/jpeg",
  "imageBase64": "..."
}
```

Response:

```json
{
  "success": true,
  "provider": "replicate",
  "featureId": "face",
  "mimeType": "image/png",
  "imageBase64": "..."
}
```

## Vercel limitation

Vercel free functions can time out on slow AI jobs. This is good for testing/MVP. For production or slow models, use a longer-running backend later.
