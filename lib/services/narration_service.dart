import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../i18n.dart';

class NarrationException implements Exception {
  final String message;
  NarrationException(this.message);
  @override
  String toString() => message;
}

// Asks the helper for a short spoken narration for each slide, in order.
Future<List<String>> fetchNarrations({
  required Uint8List pdfBytes,
  required int slideCount,
}) async {
  if (isHostedBackend && pdfBytes.lengthInBytes > maxHostedPdfBytes) {
    throw NarrationException(appStrings.pdfTooLargeOnline);
  }

  final uri = Uri.parse('$helperBaseUrl/narrate');
  final body = jsonEncode({
    'pdfBase64': base64Encode(pdfBytes),
    'slideCount': slideCount,
    'lang': appLang,
  });

  http.Response response;
  try {
    response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 150));
  } catch (_) {
    throw NarrationException(appStrings.couldNotReachHelper);
  }

  if (response.statusCode != 200) {
    throw NarrationException(_readError(response.body));
  }

  try {
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    return (j['narrations'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
  } catch (_) {
    throw NarrationException(appStrings.readLectureError);
  }
}

String _readError(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['error'] ?? appStrings.prepareLectureError).toString();
  } catch (_) {
    return appStrings.prepareLectureError;
  }
}
