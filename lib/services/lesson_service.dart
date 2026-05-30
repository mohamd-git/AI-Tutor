import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../i18n.dart';
import '../models/lesson.dart';

// A friendly error we can show the user directly.
class LessonException implements Exception {
  final String message;
  LessonException(this.message);
  @override
  String toString() => message;
}

// Sends the PDF to the secure helper and returns the lesson it makes.
Future<LessonSet> generateLesson({
  required Uint8List pdfBytes,
  required String fileName,
}) async {
  if (isHostedBackend && pdfBytes.lengthInBytes > maxHostedPdfBytes) {
    throw LessonException(appStrings.pdfTooLargeOnline);
  }

  final uri = Uri.parse('$helperBaseUrl/generate');
  final body = jsonEncode({
    'pdfBase64': base64Encode(pdfBytes),
    'fileName': fileName,
    'lang': appLang,
  });

  http.Response response;
  try {
    response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 120));
  } catch (_) {
    throw LessonException(appStrings.couldNotReachHelperLong);
  }

  if (response.statusCode != 200) {
    throw LessonException(_readError(response.body));
  }

  Map<String, dynamic> json;
  try {
    json = jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    throw LessonException(appStrings.lessonReadError);
  }

  final lessonSet = LessonSet.fromJson(json);
  if (lessonSet.topics.isEmpty) {
    throw LessonException(appStrings.noTopics);
  }
  return lessonSet;
}

String _readError(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['error'] ?? appStrings.makeLessonError).toString();
  } catch (_) {
    return appStrings.makeLessonError;
  }
}
