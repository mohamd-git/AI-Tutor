// Shared backend helper for the deployed (Vercel) version of Slide Tutor.
//
// It does the same job as server/dev_server.dart does on your PC: it keeps the
// Gemini API key on the SERVER (never in the browser) and talks to Google's
// free Gemini models for the app. Each function under /api uses these helpers.
//
// The key is read from the GEMINI_API_KEY environment variable, which you set
// once in the Vercel dashboard (Project -> Settings -> Environment Variables).
// It is never sent to the browser and never committed to GitHub.

// Free models to try, in order of preference (newest and smartest first).
// Google's free tier counts usage SEPARATELY per model, so if one is busy
// (HTTP 429), a different free model usually still works.
const CANDIDATE_MODELS = [
  'gemini-3.5-flash',
  'gemini-3-flash-preview',
  'gemini-flash-latest',
  'gemini-2.5-flash',
  'gemini-2.0-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.0-flash-lite',
];

// Remembers the last model that answered, so the next call starts with it.
let lastGoodModel = CANDIDATE_MODELS[0];

function getApiKey() {
  const k = process.env.GEMINI_API_KEY;
  return k && k.trim() ? k.trim() : null;
}

// Sends one prepared payload to Google, trying models in order until one
// answers. Returns the model's text. A 400 means the request itself was bad
// (for example a PDF that is too large), so we stop instead of retrying.
async function sendToGemini(apiKey, payload, model) {
  const order = model
    ? [model]
    : [lastGoodModel, ...CANDIDATE_MODELS.filter((m) => m !== lastGoodModel)];
  let lastError = 'No model answered.';
  for (const m of order) {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${m}` +
      `:generateContent?key=${apiKey}`;
    let status;
    let text;
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      status = resp.status;
      text = await resp.text();
    } catch (e) {
      lastError = String(e);
      continue;
    }
    if (status === 200) {
      const decoded = JSON.parse(text);
      const candidates = decoded.candidates;
      if (!candidates || candidates.length === 0) {
        lastError = 'no answer';
        continue;
      }
      const parts = candidates[0].content.parts || [];
      if (!model) lastGoodModel = m;
      return parts.map((p) => p.text || '').join('');
    }
    if (status === 400) {
      throw 'HTTP 400';
    }
    lastError = `HTTP ${status}`;
  }
  throw lastError;
}

// One-shot generation (lesson, narration, ask). Mirrors _callGemini in the
// Dart helper.
async function callGemini(apiKey, parts, opts = {}) {
  const {
    model,
    jsonOut = false,
    fast = false,
    maxTokens = 16384,
    think = false,
  } = opts;
  const payload = { contents: [{ parts }] };
  if (jsonOut) {
    const cfg = {
      responseMimeType: 'application/json',
      maxOutputTokens: maxTokens,
      temperature: 0.3,
    };
    // Let the model "think" only for the big lesson; off elsewhere for speed.
    if (!think) cfg.thinkingConfig = { thinkingBudget: 0 };
    payload.generationConfig = cfg;
  } else if (fast) {
    payload.generationConfig = {
      maxOutputTokens: 1024,
      temperature: 0.3,
      thinkingConfig: { thinkingBudget: 0 },
    };
  }
  return sendToGemini(apiKey, payload, model);
}

// A chat turn: a system instruction plus the back-and-forth so far.
async function chatGemini(apiKey, systemText, contents, model) {
  const payload = {
    systemInstruction: { parts: [{ text: systemText }] },
    contents,
    generationConfig: {
      maxOutputTokens: 1024,
      temperature: 0.3,
      thinkingConfig: { thinkingBudget: 0 },
    },
  };
  return sendToGemini(apiKey, payload, model);
}

// Turns an error into a short friendly message (English or Arabic), matching
// the messages the local dev helper shows.
function friendlyError(e, lang = 'en') {
  const s = String(e);
  const ar = lang === 'ar';
  if (s.includes('429')) {
    return ar
      ? 'تم بلوغ الحد المجاني للذكاء الاصطناعي. انتظر دقيقة وحاول مرة أخرى. ' +
          'إذا استمر الأمر، فقد تكون حصة اليوم المجانية قد نفدت (تتجدّد يومياً).'
      : 'The free AI limit was reached. Wait about a minute and try again. ' +
          "If it keeps happening, today's free quota may be used up (it resets daily).";
  }
  if (
    s.includes('Unexpected') ||
    s.includes('JSON') ||
    s.includes('Unterminated') ||
    s.includes('FormatException')
  ) {
    return ar
      ? 'انقطع الدرس قبل أن يكتمل. حاول مرة أخرى، أو جرّب ملف PDF أصغر قليلاً.'
      : 'The lesson got cut off before it finished. Please try again, ' +
          'or try a slightly smaller PDF.';
  }
  if (s.includes('400')) {
    return ar
      ? 'تعذّر على الذكاء الاصطناعي قراءة هذا الطلب. قد يكون ملف PDF كبيراً جداً. جرّب ملفاً أصغر.'
      : 'The AI could not read that request. The PDF may be too large. ' +
          'Try a smaller PDF.';
  }
  return ar
    ? 'تعذّر إنشاء الدرس. حاول مرة أخرى.'
    : 'Could not generate the lesson. Please try again.';
}

// Reads and JSON-parses the request body. Vercel usually pre-parses JSON into
// req.body; if it gave us a string or a raw stream instead, we handle that too.
async function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  let raw = '';
  if (typeof req.body === 'string') {
    raw = req.body;
  } else {
    raw = await new Promise((resolve, reject) => {
      let data = '';
      req.on('data', (chunk) => {
        data += chunk;
      });
      req.on('end', () => resolve(data));
      req.on('error', reject);
    });
  }
  if (!raw) return {};
  return JSON.parse(raw);
}

function addCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(res, status, data) {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.status(status).send(JSON.stringify(data));
}

module.exports = {
  CANDIDATE_MODELS,
  getApiKey,
  callGemini,
  chatGemini,
  friendlyError,
  readJsonBody,
  addCors,
  sendJson,
};
