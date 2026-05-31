// GET /.well-known/assetlinks.json  (routed here by the rewrite in vercel.json)
//
// Serves the Digital Asset Links statement that tells Android the Slide Tutor
// app (a Trusted Web Activity) is allowed to open this site. Once this is live,
// the installed app verifies it and drops the browser address bar, so it looks
// like a normal full-screen app. The statement is the exact file PWABuilder
// generated for this app's signing key.
const statements = require('../_shared/assetlinks.json');

module.exports = (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.status(200).send(JSON.stringify(statements));
};
