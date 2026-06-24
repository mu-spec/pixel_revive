# PixelRevive Backend Proxy

Secure Node.js backend proxy for PixelRevive cloud AI enhancement.

## Why this exists

Do **not** put Replicate/Fal.ai API keys inside Flutter code. Flutter code is compiled into the APK and can be extracted.

Use this flow instead:

```text
Flutter App → Backend Proxy → Replicate/Fal.ai
```

## Local setup

```bash
cd backend
npm install
cp .env.example .env
# put your real REPLICATE_API_TOKEN in .env locally only
npm run dev
```

Test:

```bash
curl http://localhost:8080/health
```

## Deploy on Render

1. Push this repo to GitHub.
2. Go to Render → New → Web Service.
3. Select the repo.
4. Root directory: `backend`
5. Build command: `npm install`
6. Start command: `npm start`
7. Add environment variables:

```text
DEFAULT_AI_PROVIDER=replicate
REPLICATE_API_TOKEN=your_new_replicate_token
MAX_JSON_MB=25
MAX_IMAGE_MB=8
REQUEST_TIMEOUT_MS=180000
```

Optional:

```text
FAL_API_KEY=your_fal_key
CLIENT_SHARED_SECRET=some_random_secret
```

8. Deploy.
9. Copy the public Render URL.
10. Put that URL into Flutter:

```dart
// lib/services/cloud_api_config.dart
static const String backendBaseUrl = 'https://your-service.onrender.com';
```

Do not put the Replicate key into Flutter.

## API

### GET `/health`

Returns backend status.

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

## Model overrides

You can override default Replicate models with env vars:

```text
REPLICATE_FACE_MODEL=tencentarc/gfpgan
REPLICATE_RESTORE_MODEL=tencentarc/gfpgan
REPLICATE_AUTO_MODEL=tencentarc/gfpgan
REPLICATE_UPSCALE_MODEL=nightmareai/real-esrgan
REPLICATE_BG_CLEANUP_MODEL=lucataco/remove-bg
```

Use either `owner/model` or `owner/model:version`.
