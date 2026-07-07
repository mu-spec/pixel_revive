# PixelRevive Gemini Backend

This backend replaces the old Fal.ai backend with the official Google Gemini API using `@google/genai`.

## Required environment variable

```bash
GEMINI_API_KEY=your_google_ai_studio_key
```

Do not put this key inside the Flutter app. Keep it only on Render, Northflank, Vercel, or your server.

## Local run

```bash
cd backend
npm install
GEMINI_API_KEY=your_key npm start
```

Health check:

```bash
curl http://localhost:3000/health
```

Model map:

```bash
curl http://localhost:3000/model-map
```

## API used by the Flutter app

- `POST /enhance/start` starts a Gemini job and returns `predictionId`.
- `GET /enhance/status/:id` polls the result.
- `POST /enhance` synchronous JSON fallback.

## Multipart endpoint

`POST /api/enhance` accepts `multipart/form-data`:

- `image`: image file
- `feature`: feature id, for example `auto`, `face`, `upscale`, `colorize`, `background_change`

It returns raw image bytes.

## Important note about model names

If Gemini returns a model-not-found error, set these environment variables to the exact image model IDs available in your Google AI Studio account:

```bash
GEMINI_FLASH_IMAGE_MODEL=
GEMINI_PRO_IMAGE_MODEL=
GEMINI_LITE_IMAGE_MODEL=
```
