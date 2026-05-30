import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../i18n.dart';

class ChatException implements Exception {
  final String message;
  ChatException(this.message);
  @override
  String toString() => message;
}

// Sends the conversation (plus the lesson as context) to the helper and
// returns the tutor's reply.
Future<String> askTutor({
  required String context,
  required List<Map<String, String>> messages,
}) async {
  final uri = Uri.parse('$helperBaseUrl/chat');
  final body = jsonEncode({
    'context': context,
    'messages': messages,
    'lang': appLang,
  });

  http.Response response;
  try {
    response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));
  } catch (_) {
    throw ChatException(appStrings.couldNotReachHelper);
  }

  if (response.statusCode != 200) {
    throw ChatException(_readError(response.body));
  }

  try {
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = (j['reply'] ?? '').toString();
    if (reply.isEmpty) {
      throw ChatException(appStrings.tutorEmpty);
    }
    return reply;
  } on ChatException {
    rethrow;
  } catch (_) {
    throw ChatException(appStrings.couldNotReadAnswer);
  }
}

String _readError(String body) {
  try {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return (j['error'] ?? appStrings.genericTryAgain).toString();
  } catch (_) {
    return appStrings.genericTryAgain;
  }
}
