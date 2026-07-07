# PixelRevive Gemini Backend

This backend replaces the old Fal.ai backend with the official Google Gemini API using `@google/genai`.

It is now Vercel-compatible:

- `POST /enhance/start` processes Gemini inside the same request and returns the final image directly.
- No background in-memory job is required for Vercel serverless.
- `GET /enhance/status/:id` is kept only for old app compatibility.

## Required environment variable

Set this in Vercel Project Settings → Environment Variables:

```bash
GEMINI_API_KEY=your_google_ai_studio_key
```

Do not put this key inside the Flutter app. Keep it only on Vercel/backend.

## Vercel deploy

Your project already has:

```text
backend/api/index.js
backend/vercel.json
```

After pushing to GitHub, Vercel should redeploy automatically.

Test:

```text
https://pixel-reviveapp.vercel.app/health
https://pixel-reviveapp.vercel.app/model-map
```

`/health` should show:

```json
"provider": "gemini",
"geminiConfigured": true,
"vercelCompatible": true
```

## Important note about model names

If Gemini returns a model-not-found error, set these Vercel environment variables to the exact image model IDs available in your Google AI Studio account:

```bash
GEMINI_FLASH_IMAGE_MODEL=
GEMINI_PRO_IMAGE_MODEL=
GEMINI_LITE_IMAGE_MODEL=
```

Current defaults are from your requested setup:

```bash
gemini-3.1-flash-image-preview
gemini-3-pro-image-preview
gemini-3.1-flash-lite-image-preview
```
