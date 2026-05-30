// Where the secure helper (the part that holds the API key) lives.
//
// There are two situations, and the app picks the right one automatically:
//
// 1) DEVELOPING ON YOUR PC: you run the helper as a separate program with
//    `dart run server/dev_server.dart`. It listens on port 8787. The web app is
//    opened from localhost (or, when testing on your phone, from your PC's
//    192.168.x.x address on the same Wi-Fi), so the helper is on that same host
//    at :8787.
//
// 2) DEPLOYED FOR REAL (e.g. on Vercel): the backend runs on the SAME website
//    under the /api path (see the api/ folder). Calls stay same-origin, so
//    there is no CORS to worry about and the key stays safely on the server.
import 'package:flutter/foundation.dart' show kIsWeb;

final String helperBaseUrl = _resolveHelperBaseUrl();

// True when we are talking to the hosted /api backend (Vercel) rather than the
// local dev helper. The hosted backend has a request-size limit, so the PDF
// services use this to warn before sending a too-large file.
final bool isHostedBackend = helperBaseUrl.endsWith('/api');

// The hosted backend (Vercel) limits a request body to ~4.5 MB. A PDF is sent
// base64-encoded, which is ~1.37x its real size, so we cap the raw PDF at 3 MB
// (about 4.1 MB encoded) to stay safely under that limit. The local dev helper
// has no such limit, so this only applies when [isHostedBackend] is true.
const int maxHostedPdfBytes = 3 * 1024 * 1024;

String _resolveHelperBaseUrl() {
  if (kIsWeb && Uri.base.host.isNotEmpty) {
    if (_isLocalDevHost(Uri.base.host)) {
      return 'http://${Uri.base.host}:8787';
    }
    // Deployed: backend is on the same site under /api.
    return '${Uri.base.origin}/api';
  }
  return 'http://localhost:8787';
}

// True for addresses that mean "this is local development": localhost itself,
// and the private network ranges a phone would use on the same Wi-Fi.
bool _isLocalDevHost(String host) {
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host.startsWith('192.168.') || host.startsWith('10.')) return true;
  if (host.startsWith('172.')) {
    final parts = host.split('.');
    if (parts.length >= 2) {
      final second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) return true;
    }
  }
  return false;
}
