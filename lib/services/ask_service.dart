import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../i18n.dart';

class AskException implements Exception {
  final String message;
  AskException(this.message);
  @override
  String toString() => message;
}

// Sends the student's question about the slide they are currently looking at
// to the helper, and returns a short spoken answer.
Future<String> askAboutSlide({
  required Uint8List pdfBytes,
  required int slideNumber, // 1-based
  required String question,
}) async {
  if (isHostedBackend && pdfBytes.lengthInBytes > maxHostedPdfBytes) {
    throw AskException(appStrings.pdfTooLargeOnline);
  }

  final uri = Uri.parse('$helperBaseUrl/ask');
  final body = jsonEncode({
    'pdfBase64': base64Encode(pdfBytes),
    'slideNumber': slideNumber,
    'question': question,
    'lang': appLang,
  });

  http.Response response;
  try {
    response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 120));
  } catch (_) {
    throw AskException(appStrings.couldNotReachHelper);
  }

  if (response.statusCode != 200) {
    throw AskException(_readError(response.body));
  }

  try {
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = (j['answer'] ?? '').toString().trim();
    if (answer.isEmpty) {
      throw AskException(appStrings.tutorNoAnswer);
    }
    return answer;
  } on AskException {
    rethrow;
  } catch (_) {
    throw AskException(appStrings.couldNotReadAnswer);
  }
}

String _readError(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['error'] ?? appStrings.answerQuestionError).toString();
  } catch (_) {
    return appStrings.answerQuestionError;
  }
}
