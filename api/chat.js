// POST /api/chat
// The chatbot tutor: answers the student's questions using the lesson as
// context. Mirrors the /chat route of the local dev helper.

const {
  getApiKey,
  chatGemini,
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
    const lessonContext = (data.context ?? '').toString();
    lang = data.lang === 'ar' ? 'ar' : 'en';
    const messages = Array.isArray(data.messages) ? data.messages : [];
    const contents = messages
      .filter((m) => m && typeof m === 'object')
      .map((m) => ({
        role: m.role === 'model' ? 'model' : 'user',
        parts: [{ text: (m.text ?? '').toString() }],
      }));
    if (contents.length === 0) {
      sendJson(res, 400, { error: 'No message to answer.' });
      return;
    }
    const langRule =
      lang === 'ar'
        ? ' Always reply in Arabic (Modern Standard Arabic), whatever ' +
          'language the question uses.'
        : '';
    const systemText =
      'You are a friendly, patient tutor for a complete beginner. ' +
      'Answer in simple, short, plain words. Do not use markdown symbols ' +
      `like ** or #.${langRule} Base your answers on this lesson material:\n\n${lessonContext}`;
    const reply = await chatGemini(apiKey, systemText, contents);
    sendJson(res, 200, { reply: reply.trim() });
  } catch (e) {
    sendJson(res, 500, {
      error:
        lang === 'ar'
          ? 'تعذّر الحصول على إجابة. حاول مرة أخرى.'
          : 'Could not get an answer. Please try again.',
      detail: String(e),
    });
  }
};
