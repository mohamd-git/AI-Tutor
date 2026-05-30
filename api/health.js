// GET /api/health
// A tiny check you can open in a browser to confirm the server has its key.
// It only says true/false - it NEVER reveals the key itself.

const { getApiKey } = require('../_shared/gemini');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.status(200).json({ keyLoaded: getApiKey() != null });
};
