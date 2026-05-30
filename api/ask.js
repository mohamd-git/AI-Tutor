// POST /api/ask
// Answers a question the student asks about the slide they are looking at.
// Mirrors the /ask route of the local dev helper.

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
    const slideNumber = Number.parseInt(data.slideNumber, 10) || 1;
    const question = (data.question ?? '').toString().trim();
    if (!pdfBase64) {
      sendJson(res, 400, { error: 'No PDF data received.' });
      return;
    }
    if (!question) {
      sendJson(res, 400, { error: 'No question was asked.' });
      return;
    }
    const langRule =
      lang === 'ar' ? ' Reply in Arabic (Modern Standard Arabic).' : '';
    const prompt =
      'You are a friendly, patient tutor for a complete beginner who is ' +
      'watching these slides as a lecture. The student is now looking at ' +
      `slide ${slideNumber} and asked this question out loud:\n\n` +
      `"${question}"\n\n` +
      'Answer in simple, short, spoken words (about 2 to 5 sentences), as ' +
      'if you are talking to them. Base your answer on the attached slides, ' +
      `especially slide ${slideNumber}. If you use a hard word, explain it ` +
      'right away. Do not use markdown symbols like ** or #. If the ' +
      'question is not about the slides, still answer briefly and kindly.' +
      langRule;
    const parts = [
      { inlineData: { mimeType: 'application/pdf', data: pdfBase64 } },
      { text: prompt },
    ];
    const out = await callGemini(apiKey, parts, { fast: true });
    sendJson(res, 200, { answer: out.trim() });
  } catch (e) {
    sendJson(res, 500, { error: friendlyError(e, lang), detail: String(e) });
  }
};
