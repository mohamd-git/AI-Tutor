import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The settings key where we remember the chosen voice, one per language so
// the English pick and the Arabic pick do not overwrite each other.
String voicePrefKey(String langCode) =>
    langCode == 'ar' ? 'tts_voice_ar' : 'tts_voice';

// Picks the most natural FREE voice the system offers for the given language,
// honoring the user's saved choice (set in the chat's voice picker) if there
// is one. Pass langCode 'ar' for Arabic, or 'en' (the default) for English.
Future<void> applyBestVoice(FlutterTts tts, {String langCode = 'en'}) async {
  try {
    // Make sure the engine itself is set to the right language first. This
    // helps Arabic sound correct even when no named Arabic voice is installed.
    await tts.setLanguage(langCode == 'ar' ? 'ar-SA' : 'en-US');

    final list = await voicesForLang(tts, langCode);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(voicePrefKey(langCode));
    Map? chosen;
    if (saved != null) {
      for (final v in list) {
        if ((v['name'] ?? '').toString() == saved) {
          chosen = v;
          break;
        }
      }
    }
    chosen ??= _best(list);
    if (chosen != null) {
      await tts.setVoice({
        'name': (chosen['name'] ?? '').toString(),
        'locale': (chosen['locale'] ?? '').toString(),
      });
    }
    await tts.setPitch(1.0);
    await tts.setSpeechRate(1.0);
  } catch (_) {
    // Keep the default voice if anything goes wrong.
  }
}

Map? _best(List<Map> voices) {
  const priorities = ['natural', 'neural', 'online', 'google'];
  for (final key in priorities) {
    for (final v in voices) {
      if ((v['name'] ?? '').toString().toLowerCase().contains(key)) return v;
    }
  }
  return voices.isNotEmpty ? voices.first : null;
}

// Returns the voices the system has for [langCode], deduplicated by name.
// Used by the Settings voice picker and by [applyBestVoice].
Future<List<Map>> voicesForLang(FlutterTts tts, String langCode) async {
  final raw = await _rawVoices(tts);
  final list = <Map>[];
  final seen = <String>{};
  for (final v in raw) {
    if (v is Map) {
      final locale = (v['locale'] ?? '').toString().toLowerCase();
      final name = (v['name'] ?? '').toString();
      if (locale.startsWith(langCode) && name.isNotEmpty && seen.add(name)) {
        list.add(v);
      }
    }
  }
  return list;
}

// Browsers load their speech voices lazily, so the very first request can
// come back empty even when voices exist. Try a few times before giving up.
Future<List<dynamic>> _rawVoices(FlutterTts tts) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      final dynamic voices = await tts.getVoices;
      if (voices is List && voices.isNotEmpty) return voices;
    } catch (_) {
      // Try again after a short wait.
    }
    await Future.delayed(const Duration(milliseconds: 350));
  }
  return const [];
}

// ---------------------------------------------------------------------------
// "Read answers aloud" — one app-wide on/off setting, saved on the device.
// The chat screen reads this as its starting value.
// ---------------------------------------------------------------------------
const String _speakAloudKey = 'speak_aloud';

Future<bool> getSpeakAloud() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_speakAloudKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setSpeakAloud(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_speakAloudKey, value);
  } catch (_) {
    // Best-effort.
  }
}

// ---------------------------------------------------------------------------
// Speech INPUT cleanup.
// On the web, the speech recognizer can restart itself mid-listen and pile the
// same phrase up over and over (e.g. "what is a cell what is a cell what is a
// cell ..."). When the recognized text is just one phrase repeated back to
// back, collapse it to a single copy. The repeated unit must be at least two
// words, so genuine short repeats like "no no" are left untouched.
// ---------------------------------------------------------------------------
String collapseRepeatedSpeech(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  var words = trimmed.split(RegExp(r'\s+'));

  // (1) Growing pile-up. The recognizer keeps re-sending the phrase from the
  //     start, so it grows like "hello / hello can / hello can you / ..." all
  //     stuck together and the opening word repeats many times. If every pass
  //     is a prefix of the last (most complete) pass, keep only that last pass.
  //     The prefix check means a normal sentence that just happens to repeat
  //     its first word ("is it good is it bad") is left alone.
  final first = words[0].toLowerCase();
  final firstCount = words.where((w) => w.toLowerCase() == first).length;
  if (firstCount >= 3) {
    final starts = <int>[];
    for (var i = 0; i < words.length; i++) {
      if (words[i].toLowerCase() == first) starts.add(i);
    }
    final segments = [
      for (var s = 0; s < starts.length; s++)
        words.sublist(
            starts[s], s + 1 < starts.length ? starts[s + 1] : words.length)
    ];
    final last = segments.last;
    var isPileup = true;
    for (final seg in segments) {
      if (seg.length > last.length) {
        isPileup = false;
        break;
      }
      for (var i = 0; i < seg.length; i++) {
        if (seg[i].toLowerCase() != last[i].toLowerCase()) {
          isPileup = false;
          break;
        }
      }
      if (!isPileup) break;
    }
    if (isPileup) words = last;
  }

  // (2) Whole-phrase exact repetition: collapse "X X X" -> "X". The repeated
  //     unit must be at least two words, so real short repeats like "no no" are
  //     left alone.
  final n = words.length;
  if (n >= 4) {
    for (var unit = 2; unit <= n ~/ 2; unit++) {
      if (n % unit != 0) continue;
      var matches = true;
      for (var i = unit; i < n; i++) {
        if (words[i].toLowerCase() != words[i % unit].toLowerCase()) {
          matches = false;
          break;
        }
      }
      if (matches) {
        words = words.sublist(0, unit);
        break;
      }
    }
  }

  return words.join(' ');
}
