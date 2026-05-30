// GET /api/tts?lang=en|ar&q=...
// Streams spoken audio for a short piece of text from Google Translate's free
// voice endpoint (no API key, no cost). This is what lets Arabic be spoken on
// devices that have no Arabic voice installed. Mirrors the /tts route of the
// local dev helper.

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  const q = (req.query.q || '').toString().trim();
  const lang = req.query.lang === 'ar' ? 'ar' : 'en';
  if (!q) {
    res.status(400).end();
    return;
  }
  const params = new URLSearchParams({
    ie: 'UTF-8',
    client: 'tw-ob',
    tl: lang,
    q,
  });
  const url = `https://translate.google.com/translate_tts?${params.toString()}`;
  try {
    const g = await fetch(url, {
      headers: {
        // Google only serves this endpoint to things that look like a browser.
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        Referer: 'https://translate.google.com/',
      },
    });
    if (!g.ok) {
      res.status(502).end();
      return;
    }
    const buf = Buffer.from(await g.arrayBuffer());
    res.setHeader('Content-Type', 'audio/mpeg');
    // Let the browser reuse the same clip if the same text is spoken again.
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.status(200).send(buf);
  } catch (e) {
    res.status(502).end();
  }
};
