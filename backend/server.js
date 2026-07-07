import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import crypto from 'crypto';
import { GoogleGenAI } from '@google/genai';

const app = express();

const PORT = Number(process.env.PORT || 3000);
const MAX_JSON_MB = Number(process.env.MAX_JSON_MB || 25);
const MAX_IMAGE_MB = Number(process.env.MAX_IMAGE_MB || 6);
const CLIENT_SHARED_SECRET = process.env.CLIENT_SHARED_SECRET || '';
const DAILY_START_LIMIT_PER_IP = Number(process.env.DAILY_START_LIMIT_PER_IP || 40);
const FAILURE_BLOCK_THRESHOLD = Number(process.env.FAILURE_BLOCK_THRESHOLD || 8);
const FAILURE_BLOCK_MINUTES = Number(process.env.FAILURE_BLOCK_MINUTES || 30);
const RATE_LIMIT_PER_MINUTE = Number(process.env.RATE_LIMIT_PER_MINUTE || 120);
const JOB_TTL_MS = Number(process.env.JOB_TTL_MS || 20 * 60 * 1000);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_MB * 1024 * 1024 },
});

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || '' });

const ipDailyStarts = new Map();
const ipFailures = new Map();
const jobs = new Map();

app.set('trust proxy', 1);
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: `${MAX_JSON_MB}mb` }));
app.use(rateLimit({
  windowMs: 60 * 1000,
  limit: RATE_LIMIT_PER_MINUTE,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) =>
    req.path.startsWith('/enhance/status') ||
    req.path === '/health' ||
    req.path === '/model-map',
}));

const GEMINI_FLASH_IMAGE_MODEL = process.env.GEMINI_FLASH_IMAGE_MODEL || 'gemini-3.1-flash-image-preview';
const GEMINI_PRO_IMAGE_MODEL = process.env.GEMINI_PRO_IMAGE_MODEL || 'gemini-3-pro-image-preview';
const GEMINI_LITE_IMAGE_MODEL = process.env.GEMINI_LITE_IMAGE_MODEL || 'gemini-3.1-flash-lite-image-preview';

const featureConfig = {
  // PixelRevive app feature IDs
  auto: {
    model: process.env.GEMINI_AUTO_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Upscale this image to maximum definition. Remove mild motion blur, fix out-of-focus areas when possible, and balance lighting, contrast, colors, white balance, and exposure automatically. Keep the photo realistic and preserve identity.',
  },
  face: {
    model: process.env.GEMINI_FACE_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Identify human faces in this photo. Restore natural clarity to eyes, teeth, skin texture, and facial structures. Preserve the exact identity, expression, age, hairstyle, clothes, and background. Do not make the face look artificial.',
  },
  restore: {
    model: process.env.GEMINI_RESTORE_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Restore this old or damaged photograph naturally. Improve faded colors, exposure, contrast, scratches, small damage, and overall clarity while preserving the original identity, clothing, pose, and background.',
  },
  upscale: {
    model: process.env.GEMINI_UPSCALE_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Upscale this image to clean high resolution. Intelligently sharpen lines and edge boundaries without destroying details. Keep textures natural and avoid plastic skin.',
  },
  colorize: {
    model: process.env.GEMINI_COLORIZE_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Analyze this black and white photograph and colorize it with lifelike, vibrant, historically plausible, and authentic color tones. Preserve the original identity and details.',
  },
  denoise: {
    model: process.env.GEMINI_DENOISE_MODEL || GEMINI_LITE_IMAGE_MODEL,
    prompt: 'Eliminate digital noise, color artifacts, compression artifacts, and film grain while keeping edge boundaries crisp and preserving natural detail.',
  },
  unblur: {
    model: process.env.GEMINI_UNBLUR_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Detect and remove motion blur or lens blur as much as possible. Make the image sharper and clearer while preserving the original identity, shapes, colors, and realistic look.',
  },
  bg_cleanup: {
    model: process.env.GEMINI_BG_CLEANUP_MODEL || GEMINI_LITE_IMAGE_MODEL,
    prompt: 'Keep the main subject exactly as they are. Clean the surrounding environment by seamlessly removing distracting background objects, clutter, stains, or mess. Keep the final image realistic.',
  },
  cartoon: {
    model: process.env.GEMINI_CARTOON_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Convert this photo into a vibrant 3D Pixar-style digital character illustration while keeping the subject distinct identity, pose, clothing, and main composition recognizable.',
  },
  age_progression: {
    model: process.env.GEMINI_AGE_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Change only the person apparent age according to the requested target age. Preserve facial identity, pose, clothes, hairstyle, and background. Keep the result realistic.',
  },
  baby_version: {
    model: process.env.GEMINI_BABY_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Transform the person into a realistic baby or young child according to the requested age range. Preserve recognizable identity, pose, clothes style, and background as much as possible.',
  },
  background_change: {
    model: process.env.GEMINI_BACKGROUND_CHANGE_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Keep the main foreground subject unchanged. Replace only the background with a clean, professional studio backdrop with soft depth-of-field blur and realistic lighting.',
  },
  broccoli_haircut: {
    model: process.env.GEMINI_BROCCOLI_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Change only the hairstyle into a realistic broccoli-inspired curly haircut. Preserve the same face identity, expression, skin, clothes, pose, and background. Do not change gender or facial structure.',
  },

  // Extra aliases from the migration prompt
  auto_enhance: {
    model: process.env.GEMINI_AUTO_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Upscale this image to maximum definition. Remove all motion blur, fix out-of-focus areas, and balance the lighting, contrast, and exposure automatically.',
  },
  hd_upscale: {
    model: process.env.GEMINI_UPSCALE_MODEL || GEMINI_FLASH_IMAGE_MODEL,
    prompt: 'Upscale this image to clean high resolution. Intelligently sharpen all lines and edge boundaries without destroying details.',
  },
  background_cleaning: {
    model: process.env.GEMINI_BG_CLEANUP_MODEL || GEMINI_LITE_IMAGE_MODEL,
    prompt: 'Keep the main subject exactly as they are. Clean up the surrounding environment by seamlessly removing any distracting background objects or clutter.',
  },
  cartoon_effects: {
    model: process.env.GEMINI_CARTOON_MODEL || GEMINI_PRO_IMAGE_MODEL,
    prompt: 'Convert this photo into a vibrant 3D Pixar-style digital character illustration while keeping the subject distinct identity and pose recognizable.',
  },
};

const allowedFeatures = new Set(Object.keys(featureConfig));

function requireClientSecret(req, res, next) {
  if (!CLIENT_SHARED_SECRET) return next();
  const provided = req.header('x-pixelrevive-client') || '';
  if (provided !== CLIENT_SHARED_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized client' });
  }
  return next();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

function abuseGuard(req, res, next) {
  const ip = clientIp(req);
  const now = Date.now();
  const failure = ipFailures.get(ip);
  if (failure?.blockedUntil && failure.blockedUntil > now) {
    return res.status(429).json({
      success: false,
      error: 'Too many failed cloud requests. Please try again later.',
    });
  }

  const day = todayKey();
  const current = ipDailyStarts.get(ip);
  const record = current?.day === day ? current : { day, count: 0 };
  if (record.count >= DAILY_START_LIMIT_PER_IP) {
    return res.status(429).json({
      success: false,
      error: 'Daily cloud request limit reached for this network. Try again tomorrow or use offline mode.',
    });
  }
  record.count += 1;
  ipDailyStarts.set(ip, record);
  return next();
}

function markFailure(req) {
  const ip = clientIp(req);
  const now = Date.now();
  const current = ipFailures.get(ip) || { count: 0, blockedUntil: 0, lastFailureAt: 0 };
  const count = now - current.lastFailureAt > 60 * 60 * 1000 ? 1 : current.count + 1;
  const blockedUntil = count >= FAILURE_BLOCK_THRESHOLD
    ? now + FAILURE_BLOCK_MINUTES * 60 * 1000
    : current.blockedUntil || 0;
  ipFailures.set(ip, { count, blockedUntil, lastFailureAt: now });
}

function markSuccess(req) {
  const ip = clientIp(req);
  ipFailures.delete(ip);
}

function normalizeFeatureId(value) {
  const id = String(value || 'auto').trim();
  if (id === 'background_change') return 'background_change';
  if (id === 'cartoonify') return 'cartoon';
  if (id === 'background_cleaning') return 'bg_cleanup';
  if (id === 'auto_enhance') return 'auto';
  if (id === 'hd_upscale') return 'upscale';
  if (id === 'cartoon_effects') return 'cartoon';
  return id;
}

function parseExtraInput(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) return value;
  if (typeof value === 'string' && value.trim().length > 0) {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch (_) {
      return {};
    }
  }
  return {};
}

function assertImageSizeBytes(byteLength) {
  const maxBytes = MAX_IMAGE_MB * 1024 * 1024;
  if (byteLength > maxBytes) {
    throw new Error(`Image too large. Max allowed is ${MAX_IMAGE_MB}MB.`);
  }
}

function normalizeImageBase64(imageBase64, mimeType = 'image/jpeg') {
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    throw new Error('imageBase64 is required');
  }
  const dataUriMatch = imageBase64.match(/^data:([^;]+);base64,(.+)$/);
  const detectedMimeType = dataUriMatch ? dataUriMatch[1] : mimeType;
  const cleanBase64 = (dataUriMatch ? dataUriMatch[2] : imageBase64).replace(/\s/g, '');
  assertImageSizeBytes(Math.floor((cleanBase64.length * 3) / 4));
  return { mimeType: detectedMimeType || 'image/jpeg', base64: cleanBase64 };
}

async function fetchImageUrl(imageUrl) {
  const parsed = new URL(imageUrl);
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('imageUrl must use http or https');
  }
  const response = await fetch(parsed);
  if (!response.ok) throw new Error(`imageUrl download failed: HTTP ${response.status}`);
  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  assertImageSizeBytes(buffer.length);
  return {
    mimeType: response.headers.get('content-type')?.split(';')[0] || 'image/jpeg',
    base64: buffer.toString('base64'),
  };
}

async function getImageInput(req) {
  if (req.file) {
    assertImageSizeBytes(req.file.buffer.length);
    return {
      mimeType: req.file.mimetype || 'image/jpeg',
      base64: req.file.buffer.toString('base64'),
      source: 'multipart',
    };
  }

  if (req.body?.imageUrl) {
    const fetched = await fetchImageUrl(String(req.body.imageUrl));
    return { ...fetched, source: 'imageUrl' };
  }

  const normalized = normalizeImageBase64(req.body?.imageBase64, req.body?.mimeType || 'image/jpeg');
  return { ...normalized, source: 'json' };
}

function buildPrompt(featureId, extraInput = {}, body = {}) {
  const config = featureConfig[featureId] || featureConfig.auto;
  const promptParts = [config.prompt];

  const requestedPrompt = extraInput.prompt || body.prompt;
  const gender = extraInput.gender || body.gender;
  const targetAge = extraInput.target_age || extraInput.targetAge || body.target_age || body.targetAge;

  if (featureId === 'background_change' && requestedPrompt) {
    promptParts.push(`Requested background: ${requestedPrompt}`);
  } else if (featureId === 'age_progression') {
    if (targetAge) promptParts.push(`Target age: ${targetAge} years old.`);
    if (gender) promptParts.push(`Gender: ${gender}.`);
    if (requestedPrompt) promptParts.push(String(requestedPrompt));
  } else if (featureId === 'baby_version') {
    if (targetAge) promptParts.push(`Requested child age/range: ${targetAge}.`);
    if (gender) promptParts.push(`Gender: ${gender}.`);
    if (requestedPrompt) promptParts.push(String(requestedPrompt));
  } else if (featureId === 'broccoli_haircut') {
    if (gender) promptParts.push(`Gender: ${gender}. Keep gender presentation natural.`);
    if (String(gender || '').toLowerCase() === 'female') {
      promptParts.push('For female subjects, create a feminine broccoli-inspired curly hairstyle with soft voluminous curls. Do not make it a boy haircut. Preserve long feminine hair shape as much as possible.');
    }
    if (requestedPrompt) promptParts.push(String(requestedPrompt));
  } else if (requestedPrompt) {
    promptParts.push(String(requestedPrompt));
  }

  promptParts.push('Return only the edited image. Do not return explanation text unless image output is impossible.');
  return promptParts.filter(Boolean).join('\n');
}

function extractGeminiImage(response) {
  const parts = response?.candidates?.[0]?.content?.parts || response?.response?.candidates?.[0]?.content?.parts || [];
  const textParts = [];

  for (const part of parts) {
    const inlineData = part.inlineData || part.inline_data;
    if (inlineData?.data) {
      return {
        base64: inlineData.data,
        mimeType: inlineData.mimeType || inlineData.mime_type || 'image/png',
      };
    }
    if (part.text) textParts.push(part.text);
  }

  const text = textParts.join('\n').trim();
  throw new Error(text || 'Gemini API did not return an image. Check model name and Gemini image capability.');
}

async function runGemini({ featureId, imageBase64, mimeType, extraInput = {}, body = {} }) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY is not configured on the server.');
  }

  const config = featureConfig[featureId] || featureConfig.auto;
  const prompt = buildPrompt(featureId, extraInput, body);

  console.log(`[gemini] feature=${featureId} model=${config.model}`);

  const response = await ai.models.generateContent({
    model: config.model,
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          { inlineData: { data: imageBase64, mimeType: mimeType || 'image/jpeg' } },
        ],
      },
    ],
  });

  return { ...extractGeminiImage(response), model: config.model };
}

function cleanupJobs() {
  const now = Date.now();
  for (const [id, job] of jobs.entries()) {
    if (now - job.createdAt > JOB_TTL_MS) jobs.delete(id);
  }
}

function createJob(req, payload) {
  cleanupJobs();
  const id = crypto.randomUUID();
  const job = {
    id,
    createdAt: Date.now(),
    status: 'PROCESSING',
    done: false,
    result: null,
    error: null,
    model: payload.model,
  };
  jobs.set(id, job);

  runGemini(payload)
    .then((result) => {
      job.status = 'SUCCEEDED';
      job.done = true;
      job.result = result;
      job.model = result.model;
      markSuccess(req);
    })
    .catch((error) => {
      console.error('[gemini/job] error:', error);
      job.status = 'FAILED';
      job.done = true;
      job.error = error?.message || 'Gemini enhancement failed';
      markFailure(req);
    });

  return job;
}

function sendGeminiError(res, error, fallbackMessage = 'Gemini enhancement failed', extra = {}) {
  return res.status(500).json({
    success: false,
    provider: 'gemini',
    error: error?.message || fallbackMessage,
    ...extra,
  });
}

app.get('/model-map', (_req, res) => {
  res.json({
    ok: true,
    provider: 'gemini',
    sdk: '@google/genai',
    routing: Object.fromEntries(
      Object.entries(featureConfig).map(([feature, config]) => [feature, config.model]),
    ),
    note: 'If Gemini returns a model-not-found error, set GEMINI_FLASH_IMAGE_MODEL / GEMINI_PRO_IMAGE_MODEL / GEMINI_LITE_IMAGE_MODEL in Render/Northflank to the exact image model shown in Google AI Studio.',
  });
});

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'pixel-revive-backend',
    provider: 'gemini',
    geminiConfigured: Boolean(process.env.GEMINI_API_KEY),
    persistentServer: true,
    dailyStartLimitPerIp: DAILY_START_LIMIT_PER_IP,
    failureBlockThreshold: FAILURE_BLOCK_THRESHOLD,
    activeJobs: jobs.size,
  });
});

app.post('/enhance/start', requireClientSecret, abuseGuard, upload.single('image'), async (req, res) => {
  try {
    const featureId = normalizeFeatureId(req.body?.featureId || req.body?.feature || 'auto');
    if (!allowedFeatures.has(featureId)) {
      return res.status(400).json({ success: false, error: `Unsupported featureId: ${featureId}` });
    }

    const image = await getImageInput(req);
    const extraInput = parseExtraInput(req.body?.extraInput);
    const config = featureConfig[featureId] || featureConfig.auto;
    const job = createJob(req, {
      featureId,
      imageBase64: image.base64,
      mimeType: image.mimeType,
      extraInput,
      body: req.body || {},
      model: config.model,
    });

    return res.json({
      success: true,
      provider: 'gemini',
      predictionId: job.id,
      status: job.status,
      model: config.model,
    });
  } catch (error) {
    console.error('[enhance/start] error:', error);
    markFailure(req);
    return sendGeminiError(res, error, 'Gemini start failed');
  }
});

app.get('/enhance/status/:id', requireClientSecret, async (req, res) => {
  try {
    cleanupJobs();
    const id = String(req.params.id || '');
    const job = jobs.get(id);
    if (!job) {
      return res.status(404).json({ success: false, done: true, error: 'Prediction id not found or expired' });
    }

    if (!job.done) {
      return res.json({ success: true, done: false, status: job.status, model: job.model });
    }

    if (job.error) {
      return res.status(500).json({ success: false, done: true, status: job.status, error: job.error, model: job.model });
    }

    return res.json({
      success: true,
      done: true,
      status: job.status,
      provider: 'gemini',
      model: job.result.model,
      mimeType: job.result.mimeType || 'image/png',
      imageBase64: job.result.base64,
    });
  } catch (error) {
    console.error('[enhance/status] error:', error);
    return sendGeminiError(res, error, 'Status check failed', { done: true });
  }
});

async function handleSynchronousEnhance(req, res, returnRawBytes = false) {
  const featureId = normalizeFeatureId(req.body?.featureId || req.body?.feature || 'auto');
  if (!allowedFeatures.has(featureId)) {
    return res.status(400).json({ success: false, error: `Unsupported featureId: ${featureId}` });
  }

  const image = await getImageInput(req);
  const extraInput = parseExtraInput(req.body?.extraInput);

  const result = await runGemini({
    featureId,
    imageBase64: image.base64,
    mimeType: image.mimeType,
    extraInput,
    body: req.body || {},
  });
  markSuccess(req);

  if (returnRawBytes) {
    const buffer = Buffer.from(result.base64, 'base64');
    res.set('Content-Type', result.mimeType || image.mimeType || 'image/png');
    res.set('X-PixelRevive-Provider', 'gemini');
    res.set('X-PixelRevive-Model', result.model);
    return res.send(buffer);
  }

  return res.json({
    success: true,
    provider: 'gemini',
    model: result.model,
    mimeType: result.mimeType || 'image/png',
    imageBase64: result.base64,
  });
}

app.post('/enhance', requireClientSecret, abuseGuard, upload.single('image'), async (req, res) => {
  try {
    return await handleSynchronousEnhance(req, res, false);
  } catch (error) {
    console.error('[enhance] error:', error);
    markFailure(req);
    return sendGeminiError(res, error);
  }
});

// Multipart route requested by the Gemini migration prompt.
// It returns raw image bytes directly for Android/native clients that post form-data.
app.post('/api/enhance', requireClientSecret, abuseGuard, upload.single('image'), async (req, res) => {
  try {
    return await handleSynchronousEnhance(req, res, true);
  } catch (error) {
    console.error('[api/enhance] error:', error);
    markFailure(req);
    return sendGeminiError(res, error);
  }
});

app.get('/', (_req, res) => {
  res.json({ ok: true, service: 'pixel-revive-backend', provider: 'gemini' });
});

app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Not found' });
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`PixelRevive Gemini backend listening on port ${PORT}`);
  });
}

export default app;
