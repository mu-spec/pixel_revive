import express from 'express';
import enhanceHandler from './gemini_enhance_handler.js';

const app = express();
const PORT = Number(process.env.PORT || 3000);

// Unified Gemini route only. Old polling queue routes have been removed
// for Vercel compatibility.
app.all('/api/enhance', (req, res) => enhanceHandler(req, res));

app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not found. Use POST /api/enhance.',
  });
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`PixelRevive Gemini backend listening on port ${PORT}`);
  });
}

export default app;
