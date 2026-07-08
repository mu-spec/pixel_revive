# PixelRevive Gemini Vercel API

This backend uses one clean Vercel endpoint only:

```text
POST /api/enhance
```

The old polling queue flow has been removed.

The route accepts JSON base64 image data or multipart form-data and calls Google GenAI with:

```text
gemini-3.5-flash
```

It requests image output using:

```js
config: { responseModalities: ['IMAGE'] }
```

## Required Vercel Environment Variable

```env
GEMINI_API_KEY=your_google_ai_studio_key
```

Do not put the Gemini key inside Flutter.
