// POST /api/generate
// Turns an uploaded PDF of class slides into a full lesson (JSON), exactly like
// the /generate route of the local dev helper.

const {
  getApiKey,
  callGemini,
  friendlyError,
  readJsonBody,
  addCors,
  sendJson,
} = require('../_shared/gemini');

const LESSON_PROMPT = `You are a friendly tutor for a complete beginner.
The attached PDF is a set of class slides.
Teach the ENTIRE document so well that the student never needs to open the
slides again. Cover every important part, in the order it appears. Do not skip
sections. Break the material into its main topics (between 4 and 10 topics).

For EACH topic provide:
- title: a short clear title.
- summary: 1 to 2 sentences in very simple words.
- explanation: a thorough, COMPLETE explanation in simple, friendly words that
  fully teaches this part. Use short paragraphs. Explain every idea so a beginner
  understands it without the slides. If you use a hard word, explain it right away.
- terms: the important words in this topic, each with a simple plain-language
  definition. Use an empty list if there are none.
- equations: any formulas in this topic. For each, give the formula and explain
  in plain words what it means and what each symbol stands for. Use an empty list
  if there are no formulas.
- question: ONE multiple-choice question to check understanding, with 3 or 4
  options, answerIndex as the 0-based number of the correct option, and a short
  explanation of why it is correct.
- youtubeQuery: a short search phrase the student could type on YouTube to learn
  this topic.
- chart: A chart of real numbers. Be eager: add one whenever two or more real
  values from the slides can be compared - amounts, percentages, counts, dates,
  a timeline, or sizes. Use the ACTUAL numbers from the slides - NEVER invent,
  guess or estimate data. A chart has: type ("bar", "pie", or "line"), a short
  title, labels (a list of strings), and values (a list of numbers) the SAME
  length as labels, with between 2 and 12 values. Set chart to null when the
  topic has no real numbers to show.
- diagram: A picture of an IDEA, for when there are no numbers - this is what
  gives concept topics (a process, a set of steps, how things relate, or two
  things compared) a visual. Pick the type that fits: "flow" (ordered steps or
  a pipeline), "cycle" (steps that loop back to the start), "hierarchy" (a tree:
  a parent with nested children), or "comparison" (two or three things side by
  side). A diagram has: type, a short title, and nodes (a list). Each node has a
  short label (a few words), an optional short detail, and optional children (a
  list of nodes in the SAME shape - used for the branches of a hierarchy and for
  the points under each side of a comparison). For "flow" and "cycle", make each
  step its OWN node in the list with empty children - do NOT nest the steps
  inside one another. Keep labels short. Use 2 to 6 nodes. Set diagram to null
  when no picture would help.
Try hard to give EVERY topic a chart OR a diagram: use a chart when the topic
has real numbers, otherwise use a diagram to picture the idea. Only when neither
a chart nor a diagram would help should both be null.

Return ONLY a JSON object with exactly this shape:
{
  "sourceName": "a short title for the whole document",
  "topics": [
    {
      "title": "string",
      "summary": "string",
      "explanation": "string",
      "terms": [{"term": "string", "definition": "string"}],
      "equations": [{"formula": "string", "meaning": "string"}],
      "question": {"question": "string", "options": ["string", "string", "string"], "answerIndex": 0, "explanation": "string"},
      "youtubeQuery": "string",
      "chart": {"type": "bar", "title": "string", "labels": ["A", "B"], "values": [10, 20]},
      "diagram": {"type": "flow", "title": "string", "nodes": [{"label": "string", "detail": "string", "children": []}]}
    }
  ]
}
Set "chart" to null when the topic has no real numbers; set "diagram" to null
when no picture would help. For most topics exactly one of them is non-null.
Do not write anything outside the JSON.`;

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
    const fileName = data.fileName || 'Your slides';
    lang = data.lang === 'ar' ? 'ar' : 'en';
    if (!pdfBase64) {
      sendJson(res, 400, { error: 'No PDF data received.' });
      return;
    }
    const langRule =
      lang === 'ar'
        ? '\n\nVERY IMPORTANT: Write ALL text values in Arabic (Modern ' +
          'Standard Arabic) - every title, summary, explanation, term, ' +
          'definition, equation meaning, question, option and answer ' +
          'explanation. Keep the JSON keys exactly as specified, in English.'
        : '';
    const parts = [
      { inlineData: { mimeType: 'application/pdf', data: pdfBase64 } },
      { text: `${LESSON_PROMPT}\nThe document is called: ${fileName}${langRule}` },
    ];
    const out = await callGemini(apiKey, parts, {
      jsonOut: true,
      maxTokens: 16384,
      // Thinking is OFF on the hosted version: it adds ~30s+ of latency and
      // pushes content-heavy PDFs past the host's 60-second limit (HTTP 504).
      // The detailed prompt still produces good lessons without it.
      think: false,
    });
    const parsed = JSON.parse(out);
    if (!parsed.sourceName) parsed.sourceName = fileName;
    sendJson(res, 200, parsed);
  } catch (e) {
    sendJson(res, 500, { error: friendlyError(e, lang), detail: String(e) });
  }
};
