# PixelRevive Backend Proxy — Vercel Deployment

This backend keeps your Replicate/Fal.ai API keys out of the Flutter APK.

Safe flow:

```text
Flutter App → Vercel Backend Proxy → Replicate/Fal.ai API
```

## Files

```text
backend/
  api/index.js
  server.js
  package.json
  package-lock.json
  vercel.json
  .env.example
  .gitignore
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
