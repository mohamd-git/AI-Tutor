// Speaks text out loud for the app (web only).
//
// All speech plays through the helper's `/tts` route (a free online voice) in a
// browser <audio> element. We use the online voice for EVERY language because
// phone browsers refuse to start the device speech engine unless it begins in
// the exact instant of a tap; an <audio> element, once unlocked by that first
// tap, keeps playing for the rest of the lecture.
//
// One [Speaker] per screen. Call [dispose] when the screen is closed.
//
// This file uses dart:html on purpose: the app only ever runs on the web, and
// the online Arabic voice is played through a browser <audio> element.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_tts/flutter_tts.dart';

import '../config.dart';
import '../i18n.dart';
import 'voice.dart';

class Speaker {
  final FlutterTts _tts = FlutterTts();
  void Function()? _onDone;

  // Online ("cloud") Arabic voice playback, using a single reused <audio>
  // element that gets unlocked by the first user tap.
  html.AudioElement? _audio;
  List<String> _queue = const [];
  int _index = 0;
  bool _cloudActive = false;

  Speaker() {
    // flutter_tts fires this when a DEVICE-voice utterance finishes. We ignore
    // it while the online voice is playing (that path calls _onDone itself).
    _tts.setCompletionHandler(() {
      if (!_cloudActive) _onDone?.call();
    });
  }

  // The underlying engine, for screens that still let the user pick among the
  // device's own voices (the English voice picker in Settings and Chat).
  FlutterTts get engine => _tts;

  // Called when a whole spoken passage finishes. The lecture uses this to move
  // on to the next slide by itself.
  void setCompletionHandler(void Function() callback) => _onDone = callback;

  // Prepares the best device voice for the current language. Safe to await.
  Future<void> init() async {
    await applyBestVoice(_tts, langCode: appLang);
  }

  // Speaks [text] in the current app language, stopping anything already
  // playing first.
  Future<void> speak(String text) async {
    final clean = text.trim();
    // Stop anything playing WITHOUT awaiting: an await here would move the new
    // audio outside the tap that started it, and phone browsers block audio
    // that does not begin during a tap. Then start playback synchronously, so
    // the first play() runs inside the user's tap - which unlocks audio for the
    // rest of the lecture.
    _stopNow();
    if (clean.isEmpty) return;
    // The online voice (an <audio> element) for every language; it plays on
    // phones, where the device speech engine will not start on its own.
    _startCloud(clean);
  }

  // A synchronous stop, used right before starting new speech so that nothing
  // awaits between the user's tap and the new audio beginning.
  void _stopNow() {
    _cloudActive = false;
    _queue = const [];
    _index = 0;
    final audio = _audio;
    if (audio != null) {
      try {
        audio.pause();
      } catch (_) {}
    }
    try {
      _tts.stop();
    } catch (_) {}
  }

  // Stops all speech immediately (both the device voice and the online voice).
  Future<void> stop() async {
    _cloudActive = false;
    _queue = const [];
    _index = 0;
    final audio = _audio;
    if (audio != null) {
      try {
        audio.pause();
        audio.removeAttribute('src');
        audio.load();
      } catch (_) {}
    }
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // Releases resources. Call from the screen's dispose().
  void dispose() {
    _cloudActive = false;
    final audio = _audio;
    if (audio != null) {
      try {
        audio.pause();
        audio.removeAttribute('src');
      } catch (_) {}
    }
    _tts.stop();
  }

  // --- Online Arabic voice ---------------------------------------------------

  void _startCloud(String text) {
    _queue = _chunk(text);
    _index = 0;
    _cloudActive = true;
    _audio ??= _makeAudio();
    _playNext();
  }

  html.AudioElement _makeAudio() {
    final audio = html.AudioElement();
    audio.onEnded.listen((_) {
      if (_cloudActive) _playNext();
    });
    audio.onError.listen((_) {
      if (_cloudActive) _onAudioError();
    });
    return audio;
  }

  void _playNext() {
    if (!_cloudActive) return;
    if (_index >= _queue.length) {
      _cloudActive = false;
      _onDone?.call();
      return;
    }
    final piece = _queue[_index];
    _index++;
    final url =
        '$helperBaseUrl/tts?lang=$appLang&q=${Uri.encodeQueryComponent(piece)}';
    final audio = _audio!;
    audio.src = url;
    // play() returns a promise that can reject (autoplay/network). Failures
    // also arrive through the 'error' event, so just swallow this one.
    audio.play().catchError((_) {
      if (_cloudActive) _onAudioError();
    });
  }

  void _onAudioError() {
    if (!_cloudActive) return;
    if (_index <= 1) {
      // The very first piece failed: the online voice is unreachable (helper
      // not running, or no internet). Fall back to the device voice so the
      // user still hears something instead of silence.
      final text = _queue.join(' ');
      _cloudActive = false;
      _tts.speak(text);
    } else {
      // A later piece failed: skip it and keep going.
      _playNext();
    }
  }

  // Google's voice endpoint only handles short text, so split long passages
  // into pieces of at most [max] characters, breaking on spaces where possible.
  List<String> _chunk(String text, {int max = 180}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return [clean];
    final pieces = <String>[];
    final buffer = StringBuffer();
    for (final word in clean.split(' ')) {
      if (buffer.isEmpty) {
        buffer.write(word);
      } else if (buffer.length + 1 + word.length <= max) {
        buffer.write(' ');
        buffer.write(word);
      } else {
        pieces.add(buffer.toString());
        buffer.clear();
        buffer.write(word);
      }
      // Break a single word that is somehow longer than max on its own.
      while (buffer.length > max) {
        final s = buffer.toString();
        pieces.add(s.substring(0, max));
        buffer.clear();
        buffer.write(s.substring(max));
      }
    }
    if (buffer.isNotEmpty) pieces.add(buffer.toString());
    return pieces;
  }
}
