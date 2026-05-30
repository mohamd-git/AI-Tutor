import 'dart:convert';
import 'dart:io';

// Local development helper for Slide Tutor.
// It keeps your Gemini API key OUT of the web app and the browser.
// The Flutter app talks to this helper; this helper talks to Google.
//
// Run it from the ai_tutor folder:   dart run server/dev_server.dart
// It reads your key from server/gemini_key.txt (never share that file).

// Free models to try, in order of preference (newest and smartest first).
// The helper uses the first one that works; if it is busy (free limit), it
// quietly falls back down this list, since each model has its own allowance.
const List<String> candidateModels = [
  'gemini-3.5-flash', // newest, most capable free Flash
  'gemini-3-flash-preview', // "Flash 3"
  'gemini-flash-latest', // alias that always points to the newest Flash
  'gemini-2.5-flash', // strong fallback with its own separate free allowance
  'gemini-2.0-flash',
  'gemini-2.5-flash-lite', // lighter/faster last resorts
  'gemini-2.0-flash-lite',
];

String lessonModel = candidateModels.first;
const int port = 8787;

// One reusable HTTP client. Reusing it keeps the secure connection to Google
// "warm" between calls, so each lesson, narration, answer and chat reply comes
// back faster instead of paying for a fresh handshake every single time.
final HttpClient _httpClient = HttpClient()
  ..idleTimeout = const Duration(seconds: 30);

const String lessonPrompt = '''
You are a friendly tutor for a complete beginner.
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
Do not write anything outside the JSON.
''';

String? _loadKey() {
  // 1) A real environment variable. This is what deployed hosts use (e.g. a
  //    Cloudflare Worker or any server) - the safest place for a secret.
  final envKey = Platform.environment['GEMINI_API_KEY'];
  if (envKey != null && envKey.trim().isNotEmpty) return envKey.trim();

  // 2) A local server/.env file (KEY=value lines). Git-ignored, so it never
  //    reaches GitHub. This is the normal way to run the helper on your PC.
  final fromEnv = _readEnvFile()['GEMINI_API_KEY'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // 3) Legacy fallback: the older plain-text key file, if you still have one.
  try {
    final file = File.fromUri(Platform.script.resolve('gemini_key.txt'));
    if (file.existsSync()) {
      final value = file.readAsStringSync().trim();
      if (value.isNotEmpty && value != 'PASTE_YOUR_GEMINI_KEY_HERE') {
        return value;
      }
    }
  } catch (_) {}
  return null;
}

// Reads simple KEY=value lines from server/.env into a map. Blank lines and
// lines starting with # are skipped, and surrounding quotes are removed.
// Returns an empty map if there is no .env file.
Map<String, String> _readEnvFile() {
  final out = <String, String>{};
  try {
    final file = File.fromUri(Platform.script.resolve('.env'));
    if (!file.existsSync()) return out;
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (key.isNotEmpty) out[key] = value;
    }
  } catch (_) {}
  return out;
}

void _addCors(HttpResponse res) {
  res.headers.set('Access-Control-Allow-Origin', '*');
  res.headers.set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.headers.set('Access-Control-Allow-Headers', 'Content-Type');
}

Future<void> _json(HttpResponse res, int status, Object data) async {
  res.statusCode = status;
  res.headers.contentType = ContentType.json;
  res.write(jsonEncode(data));
  await res.close();
}

// Fetches spoken audio for [text] from Google Translate's free voice endpoint
// and streams it straight back to the app. No API key and no cost. It works
// even for languages the device has no installed voice for, which is the whole
// reason Arabic needs it. The app sends short pieces (<= ~200 chars), so one
// request returns one audio clip.
Future<void> _streamTts(HttpResponse res, String text, String lang) async {
  final url = Uri.https('translate.google.com', '/translate_tts', {
    'ie': 'UTF-8',
    'client': 'tw-ob',
    'tl': lang,
    'q': text,
  });
  try {
    final gReq = await _httpClient.getUrl(url);
    // Google only serves this endpoint to things that look like a browser.
    gReq.headers.set(
        HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
    gReq.headers.set(HttpHeaders.refererHeader, 'https://translate.google.com/');
    final gRes = await gReq.close();
    if (gRes.statusCode != 200) {
      res.statusCode = 502;
      await res.close();
      return;
    }
    res.headers.contentType = ContentType('audio', 'mpeg');
    // Let the browser reuse the same clip if the same text is spoken again.
    res.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400');
    await res.addStream(gRes);
    await res.close();
  } catch (e) {
    stderr.writeln('tts error: $e');
    try {
      res.statusCode = 502;
      await res.close();
    } catch (_) {}
  }
}

// Sends one prepared request to Google and returns the model's text answer.
//
// Google's free tier counts usage SEPARATELY for each model, so when one
// model is busy (HTTP 429 "rate limited"), a different free model usually
// still works. When no specific model is given we try the last model that
// worked first, then fall back through the rest of the list until one
// answers. This keeps the app working even when a single model hits its
// free limit for the minute or the day.
Future<String> _send(
  String apiKey,
  Map<String, dynamic> payload, {
  String? model,
}) async {
  final order = model != null
      ? <String>[model]
      : <String>[
          lessonModel,
          ...candidateModels.where((m) => m != lessonModel),
        ];
  Object lastError = 'No model answered.';
  for (final m in order) {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$apiKey',
    );
    int status;
    String text;
    try {
      final request = await _httpClient.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      status = response.statusCode;
      text = await response.transform(utf8.decoder).join();
    } catch (e) {
      // A network hiccup: remember it and try the next model.
      lastError = e;
      continue;
    }
    if (status == 200) {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        lastError = 'no answer';
        continue;
      }
      final content = candidates.first['content'] as Map<String, dynamic>;
      final outParts = content['parts'] as List<dynamic>;
      // Remember the model that worked so the next request starts with it.
      if (model == null) lessonModel = m;
      return outParts.map((p) => (p as Map)['text'] ?? '').join();
    }
    // A 400 means the request itself was bad (for example a PDF that is too
    // large). Trying other models will not help, so stop and report it.
    if (status == 400) {
      throw 'HTTP 400';
    }
    // 429 (free limit reached) or any other code: remember it and try the
    // next model, which has its own separate free allowance.
    lastError = 'HTTP $status';
  }
  throw lastError;
}

Future<String> _callGemini(
  String apiKey,
  List<Map<String, dynamic>> parts, {
  String? model,
  bool jsonOut = false,
  bool fast = false,
  int maxTokens = 16384,
  bool think = false,
}) async {
  final payload = <String, dynamic>{
    'contents': [
      {'parts': parts}
    ],
  };
  if (jsonOut) {
    final cfg = <String, dynamic>{
      'responseMimeType': 'application/json',
      'maxOutputTokens': maxTokens,
      'temperature': 0.3,
    };
    // Let the model "think" for the big lesson (better charts/diagrams); keep
    // thinking off everywhere else for speed.
    if (!think) cfg['thinkingConfig'] = {'thinkingBudget': 0};
    payload['generationConfig'] = cfg;
  } else if (fast) {
    payload['generationConfig'] = {
      'maxOutputTokens': 1024,
      'temperature': 0.3,
      'thinkingConfig': {'thinkingBudget': 0},
    };
  }
  return _send(apiKey, payload, model: model);
}

String _friendlyError(Object e, [String lang = 'en']) {
  final s = e.toString();
  final ar = lang == 'ar';
  if (s.contains('429')) {
    return ar
        ? 'تم بلوغ الحد المجاني للذكاء الاصطناعي. انتظر دقيقة وحاول مرة أخرى. '
            'إذا استمر الأمر، فقد تكون حصة اليوم المجانية قد نفدت (تتجدّد يومياً).'
        : 'The free AI limit was reached. Wait about a minute and try again. '
            'If it keeps happening, today\'s free quota may be used up (it resets daily).';
  }
  if (s.contains('FormatException') ||
      s.contains('Unexpected') ||
      s.contains('Unterminated')) {
    return ar
        ? 'انقطع الدرس قبل أن يكتمل. حاول مرة أخرى، أو جرّب ملف PDF أصغر قليلاً.'
        : 'The lesson got cut off before it finished. Please try again, '
            'or try a slightly smaller PDF.';
  }
  if (s.contains('400')) {
    return ar
        ? 'تعذّر على الذكاء الاصطناعي قراءة هذا الطلب. قد يكون ملف PDF كبيراً جداً. جرّب ملفاً أصغر.'
        : 'The AI could not read that request. The PDF may be too large. '
            'Try a smaller PDF.';
  }
  return ar
      ? 'تعذّر إنشاء الدرس. حاول مرة أخرى.'
      : 'Could not generate the lesson. Please try again.';
}

Future<String> _chatGemini(
  String apiKey,
  String systemText,
  List<Map<String, dynamic>> contents, {
  String? model,
}) async {
  final payload = <String, dynamic>{
    'systemInstruction': {
      'parts': [
        {'text': systemText}
      ]
    },
    'contents': contents,
    'generationConfig': {
      'maxOutputTokens': 1024,
      'temperature': 0.3,
      'thinkingConfig': {'thinkingBudget': 0},
    },
  };
  return _send(apiKey, payload, model: model);
}

Future<void> _handle(HttpRequest req) async {
  final res = req.response;
  _addCors(res);

  if (req.method == 'OPTIONS') {
    res.statusCode = 204;
    await res.close();
    return;
  }

  final apiKey = _loadKey();

  if (req.uri.path == '/health') {
    if (req.uri.queryParameters['ping'] == '1' && apiKey != null) {
      final results = <String, String>{};
      String? working;
      for (final m in candidateModels) {
        try {
          final out = await _callGemini(
            apiKey,
            [
              {'text': 'Reply with the single word OK.'}
            ],
            model: m,
          );
          results[m] = 'ok (${out.trim()})';
          working = m;
          break;
        } catch (e) {
          results[m] = '$e';
        }
      }
      if (working != null) lessonModel = working;
      await _json(res, 200, {
        'keyLoaded': true,
        'using': working ?? 'none worked',
        'models': results,
      });
      return;
    }
    await _json(res, 200, {'keyLoaded': apiKey != null});
    return;
  }

  // Reads text aloud. The app sends one short piece of text and gets back the
  // spoken audio. This is what lets Arabic be spoken on devices that have no
  // Arabic voice installed (it uses a free online voice, no API key needed).
  if (req.method == 'GET' && req.uri.path == '/tts') {
    final q = (req.uri.queryParameters['q'] ?? '').trim();
    final lang = req.uri.queryParameters['lang'] == 'ar' ? 'ar' : 'en';
    if (q.isEmpty) {
      res.statusCode = 400;
      await res.close();
      return;
    }
    await _streamTts(res, q, lang);
    return;
  }

  if (req.method == 'POST' && req.uri.path == '/generate') {
    if (apiKey == null) {
      await _json(res, 400, {
        'error':
            'No API key found. Put your key in server/gemini_key.txt and restart the helper.'
      });
      return;
    }
    var lang = 'en';
    try {
      final raw = await utf8.decoder.bind(req).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final pdfBase64 = data['pdfBase64'] as String?;
      final fileName = (data['fileName'] as String?) ?? 'Your slides';
      lang = (data['lang'] as String?) == 'ar' ? 'ar' : 'en';
      if (pdfBase64 == null || pdfBase64.isEmpty) {
        await _json(res, 400, {'error': 'No PDF data received.'});
        return;
      }
      final langRule = lang == 'ar'
          ? '\n\nVERY IMPORTANT: Write ALL text values in Arabic (Modern '
              'Standard Arabic) - every title, summary, explanation, term, '
              'definition, equation meaning, question, option and answer '
              'explanation. Keep the JSON keys exactly as specified, in English.'
          : '';
      final parts = <Map<String, dynamic>>[
        {
          'inlineData': {'mimeType': 'application/pdf', 'data': pdfBase64}
        },
        {'text': '$lessonPrompt\nThe document is called: $fileName$langRule'},
      ];
      final out = await _callGemini(apiKey, parts,
          jsonOut: true, maxTokens: 32768, think: true);
      final parsed = jsonDecode(out) as Map<String, dynamic>;
      parsed['sourceName'] = parsed['sourceName'] ?? fileName;
      await _json(res, 200, parsed);
    } catch (e) {
      stderr.writeln('generate error: $e');
      try {
        File.fromUri(Platform.script.resolve('last_error.txt'))
            .writeAsStringSync('$e');
      } catch (_) {}
      await _json(res, 500, {'error': _friendlyError(e, lang), 'detail': '$e'});
    }
    return;
  }

  if (req.method == 'POST' && req.uri.path == '/chat') {
    if (apiKey == null) {
      await _json(res, 400, {
        'error':
            'No API key found. Put your key in server/gemini_key.txt and restart the helper.'
      });
      return;
    }
    var lang = 'en';
    try {
      final raw = await utf8.decoder.bind(req).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final lessonContext = (data['context'] ?? '').toString();
      lang = (data['lang'] as String?) == 'ar' ? 'ar' : 'en';
      final messages = data['messages'] as List<dynamic>? ?? const [];
      final contents = messages
          .whereType<Map<String, dynamic>>()
          .map((m) => {
                'role': m['role'] == 'model' ? 'model' : 'user',
                'parts': [
                  {'text': (m['text'] ?? '').toString()}
                ],
              })
          .toList();
      if (contents.isEmpty) {
        await _json(res, 400, {'error': 'No message to answer.'});
        return;
      }
      final langRule = lang == 'ar'
          ? ' Always reply in Arabic (Modern Standard Arabic), whatever '
              'language the question uses.'
          : '';
      final systemText =
          'You are a friendly, patient tutor for a complete beginner. '
          'Answer in simple, short, plain words. Do not use markdown symbols '
          'like ** or #.$langRule Base your answers on this lesson material:\n\n$lessonContext';
      final reply = await _chatGemini(apiKey, systemText, contents);
      await _json(res, 200, {'reply': reply.trim()});
    } catch (e) {
      await _json(res, 500, {
        'error': lang == 'ar'
            ? 'تعذّر الحصول على إجابة. حاول مرة أخرى.'
            : 'Could not get an answer. Please try again.',
        'detail': '$e'
      });
    }
    return;
  }

  if (req.method == 'POST' && req.uri.path == '/narrate') {
    if (apiKey == null) {
      await _json(res, 400, {
        'error':
            'No API key found. Put your key in server/gemini_key.txt and restart the helper.'
      });
      return;
    }
    var lang = 'en';
    try {
      final raw = await utf8.decoder.bind(req).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final pdfBase64 = data['pdfBase64'] as String?;
      final rawCount = data['slideCount'];
      lang = (data['lang'] as String?) == 'ar' ? 'ar' : 'en';
      final slideCount =
          rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0;
      if (pdfBase64 == null || pdfBase64.isEmpty) {
        await _json(res, 400, {'error': 'No PDF data received.'});
        return;
      }
      final langRule = lang == 'ar'
          ? 'Write every narration in Arabic (Modern Standard Arabic). '
          : '';
      final prompt =
          'The attached PDF has $slideCount slides. For EACH slide, in order '
          'from slide 1 to slide $slideCount, write a short spoken narration of '
          '2 to 4 simple sentences that teaches that slide to a complete '
          'beginner, as if you are presenting it out loud. Be friendly and '
          'clear, and explain any hard word. ${langRule}Return ONLY a JSON '
          'array of exactly $slideCount strings, in slide order. Nothing else.';
      final parts = <Map<String, dynamic>>[
        {
          'inlineData': {'mimeType': 'application/pdf', 'data': pdfBase64}
        },
        {'text': prompt},
      ];
      final out = await _callGemini(apiKey, parts, jsonOut: true);
      final decoded = jsonDecode(out);
      List<String> narrations;
      if (decoded is List) {
        narrations = decoded.map((e) => e.toString()).toList();
      } else if (decoded is Map && decoded['narrations'] is List) {
        narrations =
            (decoded['narrations'] as List).map((e) => e.toString()).toList();
      } else {
        narrations = <String>[];
      }
      await _json(res, 200, {'narrations': narrations});
    } catch (e) {
      stderr.writeln('narrate error: $e');
      await _json(res, 500, {'error': _friendlyError(e, lang), 'detail': '$e'});
    }
    return;
  }

  if (req.method == 'POST' && req.uri.path == '/ask') {
    if (apiKey == null) {
      await _json(res, 400, {
        'error':
            'No API key found. Put your key in server/gemini_key.txt and restart the helper.'
      });
      return;
    }
    var lang = 'en';
    try {
      final raw = await utf8.decoder.bind(req).join();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final pdfBase64 = data['pdfBase64'] as String?;
      final rawSlide = data['slideNumber'];
      lang = (data['lang'] as String?) == 'ar' ? 'ar' : 'en';
      final slideNumber =
          rawSlide is int ? rawSlide : int.tryParse('$rawSlide') ?? 1;
      final question = (data['question'] ?? '').toString().trim();
      if (pdfBase64 == null || pdfBase64.isEmpty) {
        await _json(res, 400, {'error': 'No PDF data received.'});
        return;
      }
      if (question.isEmpty) {
        await _json(res, 400, {'error': 'No question was asked.'});
        return;
      }
      final langRule =
          lang == 'ar' ? ' Reply in Arabic (Modern Standard Arabic).' : '';
      final prompt =
          'You are a friendly, patient tutor for a complete beginner who is '
          'watching these slides as a lecture. The student is now looking at '
          'slide $slideNumber and asked this question out loud:\n\n'
          '"$question"\n\n'
          'Answer in simple, short, spoken words (about 2 to 5 sentences), as '
          'if you are talking to them. Base your answer on the attached slides, '
          'especially slide $slideNumber. If you use a hard word, explain it '
          'right away. Do not use markdown symbols like ** or #. If the '
          'question is not about the slides, still answer briefly and kindly.$langRule';
      final parts = <Map<String, dynamic>>[
        {
          'inlineData': {'mimeType': 'application/pdf', 'data': pdfBase64}
        },
        {'text': prompt},
      ];
      final out = await _callGemini(apiKey, parts, fast: true);
      await _json(res, 200, {'answer': out.trim()});
    } catch (e) {
      stderr.writeln('ask error: $e');
      await _json(res, 500, {'error': _friendlyError(e, lang), 'detail': '$e'});
    }
    return;
  }

  await _json(res, 404, {'error': 'Not found'});
}

Future<void> main() async {
  // Bind to ALL network interfaces (not just loopback) so other devices on the
  // SAME Wi-Fi - like your phone - can reach the helper at http://<this-pc-ip>:$port.
  // This exposes the helper to your local network, so only do it on a network
  // you trust, and stop the helper (close the window) when you finish testing.
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  final key = _loadKey();
  stdout.writeln('Slide Tutor helper running on port $port');
  stdout.writeln('  On this PC:  http://localhost:$port');
  stdout.writeln('  On your LAN: http://<this-pc-ip>:$port   (open this on your phone)');
  if (key == null) {
    stdout.writeln(
        'WARNING: No API key yet. Put your key in server/gemini_key.txt, then restart.');
  } else {
    stdout.writeln('API key loaded. Ready to make lessons.');
  }
  await for (final req in server) {
    try {
      await _handle(req);
    } catch (e) {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }
}
