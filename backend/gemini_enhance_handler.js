import fs from 'fs/promises';
import { formidable } from 'formidable';
import { GoogleGenAI } from '@google/genai';

const MODEL = 'gemini-3.5-flash';
const MAX_IMAGE_MB = Number(process.env.MAX_IMAGE_MB || 6);

export const config = {
  api: {
    bodyParser: false,
  },
};

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY || '' });

const featurePrompts = {
  auto: 'Enhance this photo naturally. Improve lighting, contrast, white balance, colors, clarity, and sharpness. Preserve identity and keep the result realistic.',
  face: 'Enhance human faces naturally. Improve eyes, skin detail, teeth, and facial clarity while preserving the exact identity, expression, age, hairstyle, clothes, and background.',
  restore: 'Restore this old or damaged photograph. Improve faded colors, contrast, scratches, small damage, exposure, and clarity while preserving the original identity and composition.',
  upscale: 'Upscale and enhance this image to clean high resolution. Sharpen details and edges naturally without creating plastic skin or changing identity.',
  colorize: 'If this image is black and white, colorize it with realistic, natural, historically plausible colors. Preserve original identity and details.',
  denoise: 'Remove digital noise, compression artifacts, color artifacts, and grain while preserving natural detail and crisp edges.',
  unblur: 'Reduce motion blur and lens blur as much as possible. Make the image clearer and sharper while preserving identity and realistic details.',
  bg_cleanup: 'Keep the main subject unchanged. Remove distracting background clutter, stains, mess, or unwanted objects. Keep the final image realistic.',
  cartoon: 'Convert this photo into a vibrant 3D animated character illustration while keeping the subject identity, pose, outfit, and main composition recognizable.',
  age_progression: 'Change only the person apparent age according to the requested target age. Preserve identity, pose, clothes, hairstyle, and background. Keep the result realistic.',
  baby_version: 'Transform the person into a realistic baby or young child according to the requested age range. Preserve recognizable identity and realistic photo quality.',
  background_change: 'Keep the main foreground subject unchanged. Replace only the background with the requested background. Match lighting and perspective realistically.',
  broccoli_haircut: 'Change only the hairstyle into a realistic broccoli-inspired curly haircut. Preserve face identity, expression, skin, clothes, pose, and background.',
};

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(payload));
}

function firstValue(value) {
  return Array.isArray(value) ? value[0] : value;
}

function parseExtraInput(value) {
  value = firstValue(value);
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

function normalizeFeatureId(value) {
  const id = String(firstValue(value) || 'auto').trim();
  if (id === 'auto_enhance') return 'auto';
  if (id === 'hd_upscale') return 'upscale';
  if (id === 'background_cleaning') return 'bg_cleanup';
  if (id === 'cartoonify' || id === 'cartoon_effects') return 'cartoon';
  return id;
}

function normalizeBase64(imageBase64, mimeType = 'image/jpeg') {
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    throw new Error('imageBase64 is required');
  }
  const match = imageBase64.match(/^data:([^;]+);base64,(.+)$/);
  const cleanBase64 = (match ? match[2] : imageBase64).replace(/\s/g, '');
  const detectedMimeType = match ? match[1] : mimeType;
  const estimatedBytes = Math.floor((cleanBase64.length * 3) / 4);
  const maxBytes = MAX_IMAGE_MB * 1024 * 1024;
  if (estimatedBytes > maxBytes) {
    throw new Error(`Image too large. Max allowed is ${MAX_IMAGE_MB}MB.`);
  }
  return { base64: cleanBase64, mimeType: detectedMimeType || 'image/jpeg' };
}

async function readRawBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks).toString('utf8');
}

async function parseMultipart(req) {
  const form = formidable({
    multiples: false,
    maxFileSize: MAX_IMAGE_MB * 1024 * 1024,
    allowEmptyFiles: false,
  });

  const { fields, files } = await new Promise((resolve, reject) => {
    form.parse(req, (err, fields, files) => {
      if (err) reject(err);
      else resolve({ fields, files });
    });
  });

  const imageFile = firstValue(files.image || files.file || files.photo);
  if (!imageFile) throw new Error('No image file provided. Use multipart field name "image".');

  const buffer = await fs.readFile(imageFile.filepath);
  return {
    body: fields,
    imageBase64: buffer.toString('base64'),
    mimeType: imageFile.mimetype || 'image/jpeg',
    inputMode: 'multipart',
  };
}

async function parseRequest(req) {
  const contentType = String(req.headers['content-type'] || '').toLowerCase();

  if (contentType.includes('multipart/form-data')) {
    return parseMultipart(req);
  }

  let body = req.body;
  if (!body || typeof body !== 'object') {
    const raw = await readRawBody(req);
    body = raw ? JSON.parse(raw) : {};
  }

  const normalized = normalizeBase64(
    body.imageBase64 || body.image || body.base64,
    body.mimeType || 'image/jpeg',
  );

  return {
    body,
    imageBase64: normalized.base64,
    mimeType: normalized.mimeType,
    inputMode: 'json',
  };
}

function buildPrompt(featureId, body) {
  const extraInput = parseExtraInput(body.extraInput);
  const promptParts = [featurePrompts[featureId] || featurePrompts.auto];

  const customPrompt = firstValue(extraInput.prompt || body.prompt);
  const gender = firstValue(extraInput.gender || body.gender);
  const targetAge = firstValue(extraInput.target_age || extraInput.targetAge || body.target_age || body.targetAge);

  if (featureId === 'background_change' && customPrompt) {
    promptParts.push(`Requested background: ${customPrompt}`);
  } else if (featureId === 'age_progression') {
    if (targetAge) promptParts.push(`Target age: ${targetAge} years old.`);
    if (gender) promptParts.push(`Gender: ${gender}.`);
    if (customPrompt) promptParts.push(String(customPrompt));
  } else if (featureId === 'baby_version') {
    if (targetAge) promptParts.push(`Requested child age/range: ${targetAge}.`);
    if (gender) promptParts.push(`Gender: ${gender}.`);
    if (customPrompt) promptParts.push(String(customPrompt));
  } else if (featureId === 'broccoli_haircut') {
    if (gender) promptParts.push(`Gender: ${gender}.`);
    if (String(gender || '').toLowerCase() === 'female') {
      promptParts.push('For a female subject, create a feminine broccoli-inspired curly hairstyle with soft voluminous curls. Do not make it a boy haircut. Preserve long feminine hair shape as much as possible.');
    }
    if (customPrompt) promptParts.push(String(customPrompt));
  } else if (customPrompt) {
    promptParts.push(String(customPrompt));
  }

  promptParts.push('Return only the edited image. Do not return explanation text unless image output is impossible.');
  return promptParts.filter(Boolean).join('\n');
}

function extractImage(response) {
  const parts = response?.candidates?.[0]?.content?.parts || [];
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

  throw new Error(textParts.join('\n').trim() || 'Gemini did not return image bytes. Check whether the selected model supports image output.');
}

function isQuotaError(error) {
  const text = String(error?.message || error || '').toLowerCase();
  return error?.status === 429 || text.includes('resource_exhausted') || text.includes('quota') || text.includes('rate limit');
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-pixelrevive-client');

  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }

  if (req.method !== 'POST') {
    return sendJson(res, 405, { success: false, error: 'Method not allowed. Use POST /api/enhance.' });
  }

  try {
    if (!process.env.GEMINI_API_KEY) {
      return sendJson(res, 500, { success: false, error: 'GEMINI_API_KEY is not configured on Vercel.' });
    }

    const parsed = await parseRequest(req);
    const body = parsed.body || {};
    const featureId = normalizeFeatureId(body.featureId || body.feature || 'auto');
    const prompt = buildPrompt(featureId, body);

    console.log(`[api/enhance] Gemini model=${MODEL} feature=${featureId} input=${parsed.inputMode}`);

    const response = await ai.models.generateContent({
      model: MODEL,
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            { inlineData: { data: parsed.imageBase64, mimeType: parsed.mimeType || 'image/jpeg' } },
          ],
        },
      ],
      config: {
        responseModalities: ['IMAGE'],
      },
    });

    const image = extractImage(response);
    const wantsJson = parsed.inputMode === 'json' || String(req.headers.accept || '').includes('application/json');

    if (wantsJson) {
      return sendJson(res, 200, {
        success: true,
        provider: 'gemini',
        model: MODEL,
        featureId,
        mimeType: image.mimeType,
        imageBase64: image.base64,
      });
    }

    const buffer = Buffer.from(image.base64, 'base64');
    res.statusCode = 200;
    res.setHeader('Content-Type', image.mimeType || 'image/png');
    res.setHeader('X-PixelRevive-Provider', 'gemini');
    res.setHeader('X-PixelRevive-Model', MODEL);
    return res.end(buffer);
  } catch (error) {
    console.error('[api/enhance] error:', error);
    const status = isQuotaError(error) ? 429 : 500;
    return sendJson(res, status, {
      success: false,
      provider: 'gemini',
      model: MODEL,
      error: isQuotaError(error)
        ? 'Gemini quota exceeded. Please check Gemini billing, paid quota, or rate limits.'
        : (error?.message || 'Gemini enhancement failed'),
    });
  }
}
