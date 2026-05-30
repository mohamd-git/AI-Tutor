// POST /api/narrate
// Writes a short spoken narration for each slide, in order. Mirrors the
// /narrate route of the local dev helper.

const {
  getApiKey,
  callGemini,
  friendlyError,
  readJsonBody,
  addCors,
  sendJson,
} = require('../_shared/gemini');

module.exports = async (req, res) => {
  addCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    sendJson(res, 405, { error: 'Use POST.' });
    return;
  }
  const apiKey = getApiKey();
  if (!apiKey) {
    sendJson(res, 400, {
      error: 'No API key configured on the server (set GEMINI_API_KEY in Vercel).',
    });
    return;
  }
  let lang = 'en';
  try {
    const data = await readJsonBody(req);
    const pdfBase64 = data.pdfBase64;
    lang = data.lang === 'ar' ? 'ar' : 'en';
    const slideCount = Number.parseInt(data.slideCount, 10) || 0;
    if (!pdfBase64) {
      sendJson(res, 400, { error: 'No PDF data received.' });
      return;
    }
    const langRule =
      lang === 'ar' ? 'Write every narration in Arabic (Modern Standard Arabic). ' : '';
    const prompt =
      `The attached PDF has ${slideCount} slides. For EACH slide, in order ` +
      `from slide 1 to slide ${slideCount}, write a short spoken narration of ` +
      '2 to 4 simple sentences that teaches that slide to a complete ' +
      'beginner, as if you are presenting it out loud. Be friendly and ' +
      'clear, and explain any hard word. ' +
      langRule +
      `Return ONLY a JSON array of exactly ${slideCount} strings, in slide ` +
      'order. Nothing else.';
    const parts = [
      { inlineData: { mimeType: 'application/pdf', data: pdfBase64 } },
      { text: prompt },
    ];
    const out = await callGemini(apiKey, parts, { jsonOut: true });
    const decoded = JSON.parse(out);
    let narrations;
    if (Array.isArray(decoded)) {
      narrations = decoded.map((e) => String(e));
    } else if (decoded && Array.isArray(decoded.narrations)) {
      narrations = decoded.narrations.map((e) => String(e));
    } else {
      narrations = [];
    }
    sendJson(res, 200, { narrations });
  } catch (e) {
    sendJson(res, 500, { error: friendlyError(e, lang), detail: String(e) });
  }
};
