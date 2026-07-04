import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { fal } from '@fal-ai/client';

const app = express();

const PORT = Number(process.env.PORT || 8080);
const MAX_JSON_MB = Number(process.env.MAX_JSON_MB || 25);
const MAX_IMAGE_MB = Number(process.env.MAX_IMAGE_MB || 4);
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || 55000);
const DEFAULT_AI_PROVIDER = (process.env.DEFAULT_AI_PROVIDER || 'fal').toLowerCase();
const CLIENT_SHARED_SECRET = process.env.CLIENT_SHARED_SECRET || '';
const DAILY_START_LIMIT_PER_IP = Number(process.env.DAILY_START_LIMIT_PER_IP || 40);
const FAILURE_BLOCK_THRESHOLD = Number(process.env.FAILURE_BLOCK_THRESHOLD || 8);
const FAILURE_BLOCK_MINUTES = Number(process.env.FAILURE_BLOCK_MINUTES || 30);

// Best-effort in-memory abuse guard. On serverless this resets with cold starts,
// but it still protects warm instances. Keep Vercel rateLimit enabled too.
const ipDailyStarts = new Map();
const ipFailures = new Map();

// Fast mode defaults:
// 1) Use provider queue endpoints for long jobs, especially Fal.ai.
// 2) Return provider image URLs to the app instead of downloading + base64 re-encoding
//    inside Vercel. This removes one full image download/upload hop.
const FAL_QUEUE_ENABLED = String(process.env.FAL_QUEUE_ENABLED || 'true').toLowerCase() !== 'false';
const RETURN_IMAGE_URL = String(process.env.RETURN_IMAGE_URL || 'true').toLowerCase() !== 'false';
// Upload base64/data-URI inputs to fal's CDN before model submission. This keeps
// model requests URL-based and reduces queue payload size. If upload fails, the
// backend safely falls back to the original data URI.
const FAL_CDN_UPLOAD_ENABLED = String(process.env.FAL_CDN_UPLOAD_ENABLED || 'true').toLowerCase() !== 'false';

app.set('trust proxy', 1);
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*' }));
app.use(express.json({ limit: `${MAX_JSON_MB}mb` }));
app.use(rateLimit({
  windowMs: 60 * 1000,
  limit: Number(process.env.RATE_LIMIT_PER_MINUTE || 10),
  standardHeaders: true,
  legacyHeaders: false,
  // Status polling happens every few seconds during a cloud job. Do not block it,
  // otherwise the app gets 429 before the Fal.ai job can finish.
  skip: (req) =>
    req.path.startsWith('/enhance/status') ||
    req.path === '/health' ||
    req.path === '/model-map',
}));

const allowedFeatures = new Set([
  'auto', 'face', 'restore', 'upscale', 'colorize',
  'bg_cleanup', 'denoise', 'unblur', 'cartoon', 'bg',
  'age_progression', 'baby_version', 'background_change', 'broccoli_haircut',
]);

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
    return { mimeType: detectedMimeType, base64: cleanBase64, dataUri: `data:${detectedMimeType};base64,${cleanBase64}` };
  }
  const cleanBase64 = imageBase64.replace(/\s/g, '');
  assertImageSize(cleanBase64);
  return { mimeType, base64: cleanBase64, dataUri: `data:${mimeType};base64,${cleanBase64}` };
}

function normalizeProviderInput(body) {
  const imageUrl = typeof body.imageUrl === 'string' ? body.imageUrl.trim() : '';
  if (imageUrl) {
    let parsed;
    try { parsed = new URL(imageUrl); }
    catch (_) { throw new Error('imageUrl must be a valid URL'); }
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      throw new Error('imageUrl must use http or https');
    }
    // Fal.ai and Replicate accept remote image URLs directly. This is the fast path
    // once the Flutter app uploads inputs to Supabase/R2/Firebase/Vercel Blob.
    return { mimeType: body.mimeType || 'image/jpeg', dataUri: imageUrl, imageUrl };
  }
  return normalizeImageInput(body.imageBase64, body.mimeType || 'image/jpeg');
}

function envModel(name, fallback) { return process.env[name] || fallback; }

function normalizeScale(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return 2;
  return Math.min(4, Math.max(2, Math.round(n)));
}

function encodeJobToken(job) {
  return Buffer.from(JSON.stringify(job)).toString('base64url');
}

function decodeJobToken(token) {
  try {
    const text = Buffer.from(String(token), 'base64url').toString('utf8');
    const job = JSON.parse(text);
    return job && typeof job === 'object' ? job : null;
  } catch (_) {
    return null;
  }
}

function replicateConfigForFeature(featureId, dataUri, scale = 2) {
  const upscaleScale = normalizeScale(scale);
  const GFPGAN_VERSION = 'tencentarc/gfpgan:0fbacf7afc6c144e5be9767cff80f25aff23e52b0708f17e20f9879b2f21516c';
  switch (featureId) {
    case 'upscale': return { model: envModel('REPLICATE_UPSCALE_MODEL', 'nightmareai/real-esrgan'), input: { image: dataUri, scale: upscaleScale, face_enhance: false } };
    case 'bg_cleanup': return { model: envModel('REPLICATE_BG_CLEANUP_MODEL', 'lucataco/remove-bg'), input: { image: dataUri } };
    case 'colorize': return { model: envModel('REPLICATE_COLORIZE_MODEL', 'piddnad/ddcolor:ca494ba129e44e45f661d6ece83c4c98a9a7c774309beca01429b58fce8aa695'), input: { image: dataUri, model_size: process.env.REPLICATE_COLORIZE_MODEL_SIZE || 'large' } };
    case 'restore': return { model: envModel('REPLICATE_RESTORE_MODEL', 'microsoft/bringing-old-photos-back-to-life:c75db81db6cbd809d93cc3b7e7a088a351a3349c9fa02b6d393e35e0d51ba799'), input: { image: dataUri, HR: false, with_scratch: true } };
    case 'face': return { model: envModel('REPLICATE_FACE_MODEL', GFPGAN_VERSION), input: { img: dataUri, version: 'v1.4', scale: 2 } };
    case 'denoise': case 'unblur': return { model: envModel('REPLICATE_ENHANCE_MODEL', 'nightmareai/real-esrgan'), input: { image: dataUri, scale: 2, face_enhance: false } };
    case 'auto': default: return { model: envModel('REPLICATE_AUTO_MODEL', GFPGAN_VERSION), input: { img: dataUri, version: 'v1.4', scale: 2 } };
  }
}

async function maybeUploadToFalCdn(imageInput, fallbackMimeType = 'image/jpeg') {
  if (!FAL_CDN_UPLOAD_ENABLED) return imageInput;
  if (!imageInput || typeof imageInput !== 'string') return imageInput;
  // Already a public/presigned URL. Fal models can consume it directly.
  if (/^https?:\/\//i.test(imageInput)) return imageInput;
  if (!imageInput.startsWith('data:')) return imageInput;

  const token = process.env.FAL_API_KEY;
  if (!token) return imageInput;

  try {
    const match = imageInput.match(/^data:([^;]+);base64,(.+)$/);
    if (!match) return imageInput;
    const mimeType = match[1] || fallbackMimeType;
    const buffer = Buffer.from(match[2], 'base64');

    fal.config({ credentials: token });
    const blob = new Blob([buffer], { type: mimeType });
    const url = await fal.storage.upload(blob);
    console.log(`[fal-cdn] uploaded input ${buffer.length} bytes -> ${url}`);
    return url;
  } catch (error) {
    console.warn('[fal-cdn] upload failed; falling back to data URI:', error?.message || error);
    return imageInput;
  }
}

function falConfigForFeature(featureId, dataUri, scale = 2, isPremium = false, isHdExport = false, extraInput = {}) {
  const upscaleScale = normalizeScale(scale);
  const getEnv = (name, fallback) => process.env[name] || fallback;
  switch (featureId) {
    case 'upscale':
      if (isPremium && isHdExport) {
        return { model: getEnv('FAL_PREMIUM_HD_MODEL', 'fal-ai/aura-sr'), input: { image_url: dataUri, upscale_factor: upscaleScale, overlapping_tiles: false } };
      }
      return { model: getEnv('FAL_UPSCALE_MODEL', 'fal-ai/esrgan'), input: { image_url: dataUri, scale: upscaleScale, tile: 0, face: false, model: 'RealESRGAN_x4plus' } };
    case 'bg_cleanup':
      return { model: getEnv('FAL_BG_CLEANUP_MODEL', 'fal-ai/imageutils/rembg'), input: { image_url: dataUri, crop_to_bbox: false } };
    case 'cartoon':
      return { model: getEnv('FAL_CARTOON_MODEL', 'fal-ai/cartoonify'), input: { image_url: dataUri } };
    case 'age_progression':
      return { model: getEnv('FAL_AGE_MODEL', 'fal-ai/image-editing/age-progression'), input: { image_url: dataUri, prompt: extraInput.prompt || process.env.FAL_AGE_PROMPT || '30 years older', output_format: 'jpeg' } };
    case 'baby_version':
      return {
        // half-moon-ai/ai-baby-and-aging-generator/single returned 404 on Fal for this account.
        // Use Fal's supported age progression endpoint with a baby prompt by default.
        model: getEnv('FAL_BABY_MODEL', 'fal-ai/image-editing/age-progression'),
        input: {
          image_url: dataUri,
          prompt: extraInput.prompt || process.env.FAL_BABY_PROMPT || `as a cute ${extraInput.gender || process.env.FAL_BABY_GENDER || 'male'} baby, preserve facial identity, realistic photo`,
          output_format: 'jpeg'
        }
      };
    case 'background_change':
      return { model: getEnv('FAL_BACKGROUND_CHANGE_MODEL', 'fal-ai/image-editing/background-change'), input: { image_url: dataUri, prompt: extraInput.prompt || process.env.FAL_BACKGROUND_PROMPT || 'professional studio background, realistic lighting', guidance_scale: 3.5, num_inference_steps: 30, output_format: 'jpeg' } };
    case 'broccoli_haircut':
      return { model: getEnv('FAL_BROCCOLI_MODEL', 'fal-ai/image-editing/broccoli-haircut'), input: { image_url: dataUri } };
    case 'face':
      return { model: getEnv('FAL_FACE_MODEL', 'fal-ai/codeformer'), input: { image_url: dataUri, fidelity: 0.7, upscaling: 1, face_upscale: true } };
    case 'auto':
      // Whole-photo enhancement: use restoration/editing instead of face-only CodeFormer.
      return { model: getEnv('FAL_AUTO_MODEL', 'fal-ai/image-editing/photo-restoration'), input: { image_url: dataUri } };
    case 'restore':
      return { model: getEnv('FAL_RESTORE_MODEL', 'fal-ai/image-editing/photo-restoration'), input: { image_url: dataUri } };
    case 'colorize':
      if (isPremium) {
        return { model: getEnv('FAL_COLORIZE_MODEL', 'bria/fibo-edit/colorize'), input: { image_url: dataUri, color: process.env.FAL_COLORIZE_STYLE || 'contemporary color' } };
      }
      return { model: getEnv('FAL_COLORIZE_FAST_MODEL', 'fal-ai/image-editing/photo-restoration'), input: { image_url: dataUri } };
    case 'denoise':
      return { model: getEnv('FAL_DENOISE_MODEL', 'fal-ai/nafnet/denoise'), input: { image_url: dataUri } };
    case 'unblur':
      return { model: getEnv('FAL_UNBLUR_MODEL', 'fal-ai/nafnet/deblur'), input: { image_url: dataUri } };
    default:
      return { model: getEnv('FAL_FACE_MODEL', 'fal-ai/codeformer'), input: { image_url: dataUri, fidelity: 0.7, upscaling: 1, face_upscale: false } };
  }
}

async function fetchWithTimeout(url, options = {}, timeoutMs = REQUEST_TIMEOUT_MS) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try { return await fetch(url, { ...options, signal: controller.signal }); }
  finally { clearTimeout(timeout); }
}

function extractOutputUrl(output) {
  if (!output) return null;
  if (typeof output === 'string') return output;
  if (Array.isArray(output) && output.length > 0) return extractOutputUrl(output[0]);
  if (typeof output === 'object') {
    return output.url || output.file || output.image?.url || output.image || output.output?.url || output.output || output.images?.[0]?.url || null;
  }
  return null;
}

async function outputToResult(output, preferImageUrl = RETURN_IMAGE_URL) {
  const urlOrData = extractOutputUrl(output);
  if (!urlOrData) throw new Error('Provider returned no image output');

  if (typeof urlOrData === 'string' && urlOrData.startsWith('data:')) {
    const match = urlOrData.match(/^data:([^;]+);base64,(.+)$/);
    if (!match) throw new Error('Invalid data URI output');
    return { mimeType: match[1], imageBase64: match[2] };
  }

  if (preferImageUrl) {
    return { mimeType: 'image/png', imageUrl: String(urlOrData) };
  }

  const response = await fetchWithTimeout(urlOrData, {}, REQUEST_TIMEOUT_MS);
  if (!response.ok) throw new Error(`Failed to download provider output: HTTP ${response.status}`);
  const mimeType = response.headers.get('content-type') || 'image/png';
  const arrayBuffer = await response.arrayBuffer();
  const imageBase64 = Buffer.from(arrayBuffer).toString('base64');
  return { mimeType, imageBase64 };
}

async function runReplicate(featureId, dataUri, scale = 2) {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error('REPLICATE_API_TOKEN is not configured');
  const { model, input } = replicateConfigForFeature(featureId, dataUri, scale);
  let createUrl, body;
  if (model.includes(':')) { createUrl = 'https://api.replicate.com/v1/predictions'; body = { version: model, input }; }
  else { const [owner, name] = model.split('/'); if (!owner || !name) throw new Error(`Invalid Replicate model slug: ${model}`); createUrl = `https://api.replicate.com/v1/models/${owner}/${name}/predictions`; body = { input }; }
  const createResponse = await fetchWithTimeout(createUrl, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Prefer: 'wait=60' }, body: JSON.stringify(body) });
  const createText = await createResponse.text();
  let prediction; try { prediction = JSON.parse(createText); } catch (_) { throw new Error(`Replicate returned non-JSON response: ${createText.slice(0, 200)}`); }
  if (!createResponse.ok) throw new Error(`Replicate create failed: HTTP ${createResponse.status} ${createText}`);
  let status = prediction.status; let attempts = 0;
  while (!['succeeded', 'failed', 'canceled'].includes(status) && attempts < 90) {
    attempts += 1; await new Promise((resolve) => setTimeout(resolve, 2000));
    const pollUrl = prediction.urls?.get || `https://api.replicate.com/v1/predictions/${prediction.id}`;
    const pollResponse = await fetchWithTimeout(pollUrl, { headers: { Authorization: `Bearer ${token}` } });
    const pollText = await pollResponse.text();
    try { prediction = JSON.parse(pollText); } catch (_) { throw new Error(`Replicate poll returned non-JSON response: ${pollText.slice(0, 200)}`); }
    if (!pollResponse.ok) throw new Error(`Replicate poll failed: HTTP ${pollResponse.status} ${pollText}`);
    status = prediction.status;
  }
  if (status !== 'succeeded') throw new Error(`Replicate prediction did not succeed. Status: ${status}. Error: ${prediction.error || 'unknown'}`);
  return outputToResult(prediction.output, RETURN_IMAGE_URL);
}

async function startReplicate(featureId, dataUri, scale = 2) {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error('REPLICATE_API_TOKEN is not configured');
  const { model, input } = replicateConfigForFeature(featureId, dataUri, scale);
  let createUrl, body;
  if (model.includes(':')) { createUrl = 'https://api.replicate.com/v1/predictions'; body = { version: model, input }; }
  else { const [owner, name] = model.split('/'); if (!owner || !name) throw new Error(`Invalid Replicate model slug: ${model}`); createUrl = `https://api.replicate.com/v1/models/${owner}/${name}/predictions`; body = { input }; }
  const createResponse = await fetchWithTimeout(createUrl, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const createText = await createResponse.text();
  let prediction; try { prediction = JSON.parse(createText); } catch (_) { throw new Error(`Replicate returned non-JSON response: ${createText.slice(0, 200)}`); }
  if (!createResponse.ok) throw new Error(`Replicate create failed: HTTP ${createResponse.status} ${createText}`);
  return { id: encodeJobToken({ provider: 'replicate', id: prediction.id }), status: prediction.status, model };
}

async function checkReplicate(predictionId) {
  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) throw new Error('REPLICATE_API_TOKEN is not configured');
  const job = decodeJobToken(predictionId);
  const rawPredictionId = job?.provider === 'replicate' ? job.id : predictionId;
  const pollUrl = `https://api.replicate.com/v1/predictions/${rawPredictionId}`;
  const pollResponse = await fetchWithTimeout(pollUrl, { headers: { Authorization: `Bearer ${token}` } });
  const pollText = await pollResponse.text();
  let prediction; try { prediction = JSON.parse(pollText); } catch (_) { throw new Error(`Replicate poll returned non-JSON response: ${pollText.slice(0, 200)}`); }
  if (!pollResponse.ok) throw new Error(`Replicate poll failed: HTTP ${pollResponse.status} ${pollText}`);
  const status = prediction.status;
  if (status === 'succeeded') { const result = await outputToResult(prediction.output, RETURN_IMAGE_URL); return { status, ...result }; }
  if (status === 'failed' || status === 'canceled') throw new Error(`Replicate prediction ${status}. Error: ${prediction.error || 'unknown'}`);
  return { status };
}

async function runFal(featureId, dataUri, scale = 2, isPremium = false, isHdExport = false, extraInput = {}) {
  const token = process.env.FAL_API_KEY;
  if (!token) throw new Error('FAL_API_KEY is not configured');
  const modelInputUrl = await maybeUploadToFalCdn(dataUri);
  const { model, input } = falConfigForFeature(featureId, modelInputUrl, scale, isPremium, isHdExport, extraInput);
  const response = await fetchWithTimeout(`https://fal.run/${model}`, { method: 'POST', headers: { Authorization: `Key ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(input) });
  const text = await response.text();
  let data; try { data = JSON.parse(text); } catch (_) { throw new Error(`Fal.ai returned non-JSON response: ${text.slice(0, 200)}`); }
  if (!response.ok) throw new Error(`Fal.ai failed: HTTP ${response.status} ${text}`);
  const output = data.image?.url || data.images?.[0]?.url || data.output || data.url || data;
  return outputToResult(output, RETURN_IMAGE_URL);
}

async function startFal(featureId, dataUri, scale = 2, isPremium = false, isHdExport = false, extraInput = {}) {
  if (!FAL_QUEUE_ENABLED) throw new Error('Fal queue is disabled');
  const token = process.env.FAL_API_KEY;
  if (!token) throw new Error('FAL_API_KEY is not configured');
  const modelInputUrl = await maybeUploadToFalCdn(dataUri);
  const { model, input } = falConfigForFeature(featureId, modelInputUrl, scale, isPremium, isHdExport, extraInput);
  const response = await fetchWithTimeout(`https://queue.fal.run/${model}`, {
    method: 'POST',
    headers: { Authorization: `Key ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  const text = await response.text();
  let data; try { data = JSON.parse(text); } catch (_) { throw new Error(`Fal queue returned non-JSON response: ${text.slice(0, 200)}`); }
  if (!response.ok) throw new Error(`Fal queue submit failed: HTTP ${response.status} ${text}`);
  const requestId = data.request_id || data.requestId || data.id;
  if (!requestId) throw new Error(`Fal queue returned no request_id: ${text}`);
  return { id: encodeJobToken({ provider: 'fal', model, id: requestId }), status: data.status || 'IN_QUEUE', model };
}

async function checkFal(job) {
  const token = process.env.FAL_API_KEY;
  if (!token) throw new Error('FAL_API_KEY is not configured');
  const model = job.model;
  const requestId = job.id;
  if (!model || !requestId) throw new Error('Invalid Fal job token');

  // Use the official Fal client for queue status/result. Some Fal endpoints can
  // return empty/non-JSON bodies when polled through raw constructed URLs; the
  // client handles the correct queue API consistently across models.
  fal.config({ credentials: token });

  let statusData;
  try {
    statusData = await fal.queue.status(model, {
      requestId,
      logs: false,
    });
  } catch (clientError) {
    console.warn(`[fal-status] client status failed for ${model}/${requestId}:`, clientError?.message || clientError);
    return { status: 'IN_PROGRESS' };
  }

  const rawStatus = String(statusData?.status || statusData?.state || '').toUpperCase();

  if (['COMPLETED', 'SUCCEEDED', 'SUCCESS'].includes(rawStatus)) {
    let resultData;
    try {
      const result = await fal.queue.result(model, { requestId });
      resultData = result?.data || result;
    } catch (resultError) {
      throw new Error(`Fal result failed: ${resultError?.message || resultError}`);
    }

    const output = resultData?.image?.url ||
      resultData?.images?.[0]?.url ||
      resultData?.output ||
      resultData?.url ||
      resultData;
    const finalResult = await outputToResult(output, RETURN_IMAGE_URL);
    return { status: rawStatus, ...finalResult };
  }

  if (['FAILED', 'ERROR', 'CANCELED', 'CANCELLED'].includes(rawStatus)) {
    throw new Error(`Fal prediction ${rawStatus}. Error: ${statusData?.error || statusData?.message || 'unknown'}`);
  }

  return { status: rawStatus || 'IN_PROGRESS' };
}

app.get('/model-map', (_req, res) => {
  res.json({
    ok: true,
    provider: DEFAULT_AI_PROVIDER,
    falCdnUploadEnabled: FAL_CDN_UPLOAD_ENABLED,
    routing: {
      auto: {
        fast: process.env.FAL_AUTO_MODEL || 'fal-ai/image-editing/photo-restoration',
        balanced: process.env.FAL_AUTO_MODEL || 'fal-ai/image-editing/photo-restoration',
        hd: process.env.FAL_AUTO_MODEL || 'fal-ai/image-editing/photo-restoration',
      },
      face: process.env.FAL_FACE_MODEL || 'fal-ai/codeformer',
      upscale: {
        normal: process.env.FAL_UPSCALE_MODEL || 'fal-ai/esrgan',
        premiumHd: process.env.FAL_PREMIUM_HD_MODEL || 'fal-ai/aura-sr',
      },
      denoise: {
        fast: process.env.FAL_DENOISE_MODEL || 'fal-ai/nafnet/denoise',
        balanced: process.env.FAL_DENOISE_MODEL || 'fal-ai/nafnet/denoise',
        hd: process.env.FAL_DENOISE_MODEL || 'fal-ai/nafnet/denoise',
      },
      unblur: {
        fast: process.env.FAL_UNBLUR_MODEL || 'fal-ai/nafnet/deblur',
        balanced: process.env.FAL_UNBLUR_MODEL || 'fal-ai/nafnet/deblur',
        hd: process.env.FAL_UNBLUR_MODEL || 'fal-ai/nafnet/deblur',
      },
      colorize: {
        freeFast: process.env.FAL_COLORIZE_FAST_MODEL || 'fal-ai/image-editing/photo-restoration',
        premium: process.env.FAL_COLORIZE_MODEL || 'bria/fibo-edit/colorize',
        premiumStyle: process.env.FAL_COLORIZE_STYLE || 'contemporary color',
      },
      restore: process.env.FAL_RESTORE_MODEL || 'fal-ai/image-editing/photo-restoration',
      backgroundCleanup: process.env.FAL_BG_CLEANUP_MODEL || 'fal-ai/imageutils/rembg',
      cartoon: process.env.FAL_CARTOON_MODEL || 'fal-ai/cartoonify',
      ageProgression: process.env.FAL_AGE_MODEL || 'fal-ai/image-editing/age-progression',
      babyVersion: process.env.FAL_BABY_MODEL || 'fal-ai/image-editing/age-progression',
      backgroundChange: process.env.FAL_BACKGROUND_CHANGE_MODEL || 'fal-ai/image-editing/background-change',
      broccoliHaircut: process.env.FAL_BROCCOLI_MODEL || 'fal-ai/image-editing/broccoli-haircut',
      cartoonify: process.env.FAL_CARTOON_MODEL || 'fal-ai/cartoonify',
      backgroundBlur: 'local on-device',
    },
  });
});

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'pixel-revive-backend',
    defaultProvider: DEFAULT_AI_PROVIDER,
    replicateConfigured: Boolean(process.env.REPLICATE_API_TOKEN),
    falConfigured: Boolean(process.env.FAL_API_KEY),
    falQueueEnabled: FAL_QUEUE_ENABLED,
    returnImageUrl: RETURN_IMAGE_URL,
    falCdnUploadEnabled: FAL_CDN_UPLOAD_ENABLED,
    dailyStartLimitPerIp: DAILY_START_LIMIT_PER_IP,
    failureBlockThreshold: FAILURE_BLOCK_THRESHOLD,
  });
});

app.post('/enhance/start', requireClientSecret, abuseGuard, async (req, res) => {
  try {
    const featureId = String(req.body.featureId || 'auto');
    const provider = String(req.body.provider || DEFAULT_AI_PROVIDER).toLowerCase();
    if (!allowedFeatures.has(featureId)) return res.status(400).json({ success: false, error: `Unsupported featureId: ${featureId}` });
    if (!['replicate', 'fal'].includes(provider)) return res.status(400).json({ success: false, error: `Unsupported provider: ${provider}` });
    const normalized = normalizeProviderInput(req.body);
    const started = provider === 'fal'
      ? await startFal(featureId, normalized.dataUri, req.body.scale, Boolean(req.body.isPremium), Boolean(req.body.isHdExport), req.body.extraInput || {})
      : await startReplicate(featureId, normalized.dataUri, req.body.scale);
    markSuccess(req);
    res.json({ success: true, provider, predictionId: started.id, status: started.status, model: started.model });
  } catch (error) {
    markFailure(req);
    console.error('[enhance/start] error:', error);
    res.status(500).json({ success: false, error: error.message || 'Failed to start prediction' });
  }
});

app.get('/enhance/status/:id', requireClientSecret, async (req, res) => {
  try {
    const predictionId = String(req.params.id || '');
    if (!predictionId) return res.status(400).json({ success: false, error: 'Missing prediction id' });
    const job = decodeJobToken(predictionId);
    const result = job?.provider === 'fal' ? await checkFal(job) : await checkReplicate(predictionId);
    if (result.imageBase64 || result.imageUrl) {
      return res.json({
        success: true,
        done: true,
        status: result.status,
        mimeType: result.mimeType || 'image/png',
        imageBase64: result.imageBase64,
        imageUrl: result.imageUrl,
      });
    }
    return res.json({ success: true, done: false, status: result.status });
  } catch (error) {
    console.error('[enhance/status] error:', error);
    res.status(500).json({ success: false, done: true, error: error.message || 'Status check failed' });
  }
});

app.post('/enhance', requireClientSecret, abuseGuard, async (req, res) => {
  const startedAt = Date.now();
  try {
    const featureId = String(req.body.featureId || 'auto');
    const provider = String(req.body.provider || DEFAULT_AI_PROVIDER).toLowerCase();
    if (!allowedFeatures.has(featureId)) return res.status(400).json({ success: false, error: `Unsupported featureId: ${featureId}` });
    if (!['replicate', 'fal'].includes(provider)) return res.status(400).json({ success: false, error: `Unsupported provider: ${provider}` });
    const normalized = normalizeProviderInput(req.body);
    const result = provider === 'fal'
      ? await runFal(featureId, normalized.dataUri, req.body.scale, Boolean(req.body.isPremium), Boolean(req.body.isHdExport), req.body.extraInput || {})
      : await runReplicate(featureId, normalized.dataUri, req.body.scale);
    markSuccess(req);
    res.json({
      success: true,
      provider,
      featureId,
      mimeType: result.mimeType || 'image/png',
      imageBase64: result.imageBase64,
      imageUrl: result.imageUrl,
      elapsedMs: Date.now() - startedAt,
    });
  } catch (error) {
    markFailure(req);
    console.error('[enhance] error:', error);
    res.status(500).json({ success: false, error: error.message || 'Cloud enhancement failed', elapsedMs: Date.now() - startedAt });
  }
});

app.use((_req, res) => { res.status(404).json({ success: false, error: 'Not found' }); });

if (!process.env.VERCEL) { app.listen(PORT, () => { console.log(`PixelRevive backend listening on port ${PORT}`); }); }

export default app;
