import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

const app = express();

const PORT = Number(process.env.PORT || 8080);
const MAX_JSON_MB = Number(process.env.MAX_JSON_MB || 25);
const MAX_IMAGE_MB = Number(process.env.MAX_IMAGE_MB || 8);
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || 55000);
const DEFAULT_AI_PROVIDER = (process.env.DEFAULT_AI_PROVIDER || 'replicate').toLowerCase();
const CLIENT_SHARED_SECRET = process.env.CLIENT_SHARED_SECRET || '';

app.set('trust proxy', 1);
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: `${MAX_JSON_MB}mb` }));
app.use(rateLimit({
  windowMs: 60 * 1000,
  limit: Number(process.env.RATE_LIMIT_PER_MINUTE || 30),
  standardHeaders: true,
  legacyHeaders: false,
}));

const allowedFeatures = new Set([
  'auto',
  'face',
  'restore',
  'upscale',
  'colorize',
  'bg_cleanup',
  'denoise',
  'unblur',
  'cartoon',
  'bg',
]);

function requireClientSecret(req, res, next) {
  if (!CLIENT_SHARED_SECRET) return next();
  const provided = req.header('x-pixelrevive-client') || '';
  if (provided !== CLIENT_SHARED_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized client' });
  }
  return next();
}

function assertImageSize(base64) {
  const estimatedBytes = Math.floor((base64.length * 3) / 4);
  const maxBytes = MAX_IMAGE_MB * 1024 * 1024;
  if (estimatedBytes > maxBytes) {
    throw new Error(`Image too large. Max allowed is ${MAX_IMAGE_MB}MB.`);
  }
}

function normalizeImageInput(imageBase64, mimeType = 'image/jpeg') {
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    throw new Error('imageBase64 is required');
  }

  const dataUriMatch = imageBase64.match(/^data:([^;]+);base64,(.+)$/);
  if (dataUriMatch) {
    const detectedMimeType = dataUriMatch[1] || mimeType;
    const cleanBase64 = dataUriMatch[2];
    assertImageSize(cleanBase64);
    return {
      mimeType: detectedMimeType,
      base64: cleanBase64,
      dataUri: `data:${detectedMimeType};base64,${cleanBase64}`,
    };
  }

  const cleanBase64 = imageBase64.replace(/\s/g, '');
  assertImageSize(cleanBase64);
  return {
    mimeType,
    base64: cleanBase64,
    dataUri: `data:${mimeType};base64,${cleanBase64}`,
  };
}

function envModel(name, fallback) {
  return process.env[name] || fallback;
}

function replicateConfigForFeature(featureId, dataUri) {
  // GFPGAN is NOT an "official" Replicate model, so the model-level endpoint
  // (/v1/models/{owner}/{name}/predictions) returns 404. It MUST be called via
  // the version-pinned endpoint (/v1/predictions with {version}). Any model
  // string containing ':' below is automatically routed to that endpoint.
  // Source: https://replicate.com/tencentarc/gfpgan/api (current version hash).
  const GFPGAN_VERSION =
    'tencentarc/gfpgan:0fbacf7afc6c144e5be9767cff80f25aff23e52b0708f17e20f9879b2f21516c';

  switch (featureId) {
    case 'upscale':
      return {
        model: envModel('REPLICATE_UPSCALE_MODEL', 'nightmareai/real-esrgan'),
        input: {
          image: dataUri,
          scale: 2,
          face_enhance: false,
        },
      };

    case 'bg_cleanup':
      return {
        model: envModel('REPLICATE_BG_CLEANUP_MODEL', 'lucataco/remove-bg'),
        input: {
          image: dataUri,
        },
      };

    case 'colorize':
      return {
        model: envModel(
          'REPLICATE_COLORIZE_MODEL',
          'piddnad/ddcolor:ca494ba129e44e45f661d6ece83c4c98a9a7c774309beca01429b58fce8aa695'
        ),
        input: {
          image: dataUri,
          model_size: process.env.REPLICATE_COLORIZE_MODEL_SIZE || 'large',
        },
      };

    case 'restore':
      return {
        model: envModel(
          'REPLICATE_RESTORE_MODEL',
          'microsoft/bringing-old-photos-back-to-life:c75db81db6cbd809d93cc3b7e7a088a351a3349c9fa02b6d393e35e0d51ba799'
        ),
        input: {
          image: dataUri,
          HR: false,
          with_scratch: true,
        },
      };

    case 'face':
      return {
        model: envModel('REPLICATE_FACE_MODEL', GFPGAN_VERSION),
        input: {
          img: dataUri,
          version: 'v1.4',
          scale: 2,
        },
      };

    case 'denoise':
    case 'unblur':
      // Real-ESRGAN is an enhancement/denoise/super-res model — genuine AI
      // for noise reduction and deblurring (no extra resolution gain needed).
      return {
        model: envModel('REPLICATE_ENHANCE_MODEL', 'nightmareai/real-esrgan'),
        input: {
          image: dataUri,
          scale: 2,
          face_enhance: false,
        },
      };

    case 'auto':
    default:
      return {
        model: envModel('REPLICATE_AUTO_MODEL', GFPGAN_VERSION),
        input: {
          img: dataUri,
          version: 'v1.4',
          scale: 2,
        },
      };
  }
}

function falConfigForFeature(featureId, dataUri) {
  switch (featureId) {
    case 'upscale':
      return {
        model: envModel('FAL_UPSCALE_MODEL', 'fal-ai/esrgan'),
        input: {
          image_url: dataUri,
          upscaling: 2,
        },
      };

    case 'bg_cleanup':
      return {
        model: envModel('FAL_BG_CLEANUP_MODEL', 'fal-ai/imageutils/rembg'),
        input: {
          image_url: dataUri,
        },
      };

    case 'face':
    case 'restore':
    case 'auto':
    case 'colorize':
    default:
      return {
        model: envModel('FAL_FACE_MODEL', 'fal-ai/codeformer'),
        input: {
          image_url: dataUri,
          fidelity: 0.7,
          upscaling: 1,
          face_upscale: true,
        },
      };
  }
}

async function fetchWithTimeout(url, options = {}, timeoutMs = REQUEST_TIMEOUT_MS) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

function extractOutputUrl(output) {
  if (!output) return null;
  if (typeof output === 'string') return output;
  if (Array.isArray(output) && output.length > 0) return extractOutputUrl(output[0]);
  if (typeof output === 'object') {
    return output.url || output.file || output.image || output.output || null;
  }
  return null;
}

async function outputToBase64(output) {
  const urlOrData = extractOutputUrl(output);
  if (!urlOrData) throw new Error('Provider returned no image output');

  if (typeof urlOrData === 'string' && urlOrData.startsWith('data:')) {
    const match = urlOrData.match(/^data:([^;]+);base64,(.+)$/);
    if (!match) throw new Error('Invalid data URI output');
    return { mimeType: match[1], imageBase64: match[2] };
  }

  const response = await fetchWithTimeout(urlOrData, {}, REQUEST_TIMEOUT_MS);
  if (!response.ok) {
    throw new Error(`Failed to download provider output: HTTP ${response.status}`);
  }

  const mimeType = response.headers.get('content-type') || 'image/png';
  const arrayBuffer = await response.arrayBuffer();
  const imageBase64 = Buffer.from(arrayBuffer).toString('base64');
  return { mimeType, imageBase64 };
}

async function runReplicate(featureId, dataUri) {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error('REPLICATE_API_TOKEN is not configured');

  const { model, input } = replicateConfigForFeature(featureId, dataUri);

  let createUrl;
  let body;

  if (model.includes(':')) {
    createUrl = 'https://api.replicate.com/v1/predictions';
    body = { version: model, input };
  } else {
    const [owner, name] = model.split('/');
    if (!owner || !name) throw new Error(`Invalid Replicate model slug: ${model}`);
    createUrl = `https://api.replicate.com/v1/models/${owner}/${name}/predictions`;
    body = { input };
  }

  const createResponse = await fetchWithTimeout(createUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Prefer: 'wait=60',
    },
    body: JSON.stringify(body),
  });

  const createText = await createResponse.text();
  let prediction;
  try {
    prediction = JSON.parse(createText);
  } catch (_) {
    throw new Error(`Replicate returned non-JSON response: ${createText.slice(0, 200)}`);
  }

  if (!createResponse.ok) {
    throw new Error(`Replicate create failed: HTTP ${createResponse.status} ${createText}`);
  }

  let status = prediction.status;
  let attempts = 0;

  while (!['succeeded', 'failed', 'canceled'].includes(status) && attempts < 90) {
    attempts += 1;
    await new Promise((resolve) => setTimeout(resolve, 2000));

    const pollUrl = prediction.urls?.get || `https://api.replicate.com/v1/predictions/${prediction.id}`;
    const pollResponse = await fetchWithTimeout(pollUrl, {
      headers: { Authorization: `Bearer ${token}` },
    });

    const pollText = await pollResponse.text();
    try {
      prediction = JSON.parse(pollText);
    } catch (_) {
      throw new Error(`Replicate poll returned non-JSON response: ${pollText.slice(0, 200)}`);
    }

    if (!pollResponse.ok) {
      throw new Error(`Replicate poll failed: HTTP ${pollResponse.status} ${pollText}`);
    }

    status = prediction.status;
  }

  if (status !== 'succeeded') {
    throw new Error(`Replicate prediction did not succeed. Status: ${status}. Error: ${prediction.error || 'unknown'}`);
  }

  return outputToBase64(prediction.output);
}

async function runFal(featureId, dataUri) {
  const token = process.env.FAL_API_KEY;
  if (!token) throw new Error('FAL_API_KEY is not configured');

  const { model, input } = falConfigForFeature(featureId, dataUri);
  const response = await fetchWithTimeout(`https://fal.run/${model}`, {
    method: 'POST',
    headers: {
      Authorization: `Key ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  });

  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    throw new Error(`Fal.ai returned non-JSON response: ${text.slice(0, 200)}`);
  }

  if (!response.ok) {
    throw new Error(`Fal.ai failed: HTTP ${response.status} ${text}`);
  }

  const output = data.image?.url || data.images?.[0]?.url || data.output || data.url || data;
  return outputToBase64(output);
}

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'pixel-revive-backend',
    defaultProvider: DEFAULT_AI_PROVIDER,
    replicateConfigured: Boolean(process.env.REPLICATE_API_TOKEN),
    falConfigured: Boolean(process.env.FAL_API_KEY),
  });
});

app.post('/enhance', requireClientSecret, async (req, res) => {
  const startedAt = Date.now();

  try {
    const featureId = String(req.body.featureId || 'auto');
    const provider = String(req.body.provider || DEFAULT_AI_PROVIDER).toLowerCase();

    if (!allowedFeatures.has(featureId)) {
      return res.status(400).json({ success: false, error: `Unsupported featureId: ${featureId}` });
    }

    if (!['replicate', 'fal'].includes(provider)) {
      return res.status(400).json({ success: false, error: `Unsupported provider: ${provider}` });
    }

    const normalized = normalizeImageInput(req.body.imageBase64, req.body.mimeType || 'image/jpeg');

    const result = provider === 'fal'
      ? await runFal(featureId, normalized.dataUri)
      : await runReplicate(featureId, normalized.dataUri);

    res.json({
      success: true,
      provider,
      featureId,
      mimeType: result.mimeType,
      imageBase64: result.imageBase64,
      elapsedMs: Date.now() - startedAt,
    });
  } catch (error) {
    console.error('[enhance] error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Cloud enhancement failed',
      elapsedMs: Date.now() - startedAt,
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Not found' });
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`PixelRevive backend listening on port ${PORT}`);
  });
}

export default app;
