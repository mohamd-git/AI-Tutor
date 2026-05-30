import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../i18n.dart';
import '../models/lesson.dart';
import '../services/chat_service.dart';
import '../services/speaker.dart';
import '../services/voice.dart';

class ChatScreen extends StatefulWidget {
  final LessonSet lessonSet;
  const ChatScreen({super.key, required this.lessonSet});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  final SpeechToText _speech = SpeechToText();
  final Speaker _speaker = Speaker();

  bool _sending = false;
  bool _speakAloud = false;
  bool _listening = false;

  List<Map> _voices = [];
  String? _voiceName;

  late final String _context;

  @override
  void initState() {
    super.initState();
    _context = widget.lessonSet.topics
        .map((t) => '${t.title}\n${t.explanation}')
        .join('\n\n');
    _setupVoice();
    _initSpeakAloud();
  }

  // Start with the app-wide "read answers aloud" choice from Settings.
  Future<void> _initSpeakAloud() async {
    final on = await getSpeakAloud();
    if (mounted) setState(() => _speakAloud = on);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _speech.stop();
    _speaker.dispose();
    super.dispose();
  }

  Map? _bestVoice(List<Map> en) {
    const priorities = ['natural', 'neural', 'online', 'google'];
    for (final key in priorities) {
      for (final v in en) {
        if ((v['name'] ?? '').toString().toLowerCase().contains(key)) return v;
      }
    }
    return en.isNotEmpty ? en.first : null;
  }

  Future<void> _setupVoice() async {
    try {
      // Set the engine language first so Arabic sounds right even when no
      // named Arabic voice is installed.
      await _speaker.engine.setLanguage(appLang == 'ar' ? 'ar-SA' : 'en-US');
      final dynamic voices = await _speaker.engine.getVoices;
      final list = <Map>[];
      final seen = <String>{};
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final name = (v['name'] ?? '').toString();
            if (locale.startsWith(appLang) &&
                name.isNotEmpty &&
                seen.add(name)) {
              list.add(v);
            }
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(voicePrefKey(appLang));
      Map? chosen;
      if (savedName != null) {
        for (final v in list) {
          if ((v['name'] ?? '').toString() == savedName) {
            chosen = v;
            break;
          }
        }
      }
      chosen ??= _bestVoice(list);
      if (chosen != null) {
        await _speaker.engine.setVoice({
          'name': (chosen['name'] ?? '').toString(),
          'locale': (chosen['locale'] ?? '').toString(),
        });
      }
      await _speaker.engine.setPitch(1.0);
      await _speaker.engine.setSpeechRate(1.0);
      if (mounted) {
        setState(() {
          _voices = list;
          _voiceName = chosen != null ? (chosen['name'] ?? '').toString() : null;
        });
      }
    } catch (_) {
      // Keep the default voice if anything goes wrong.
    }
  }

  Future<void> _selectVoice(String name) async {
    Map? v;
    for (final item in _voices) {
      if ((item['name'] ?? '').toString() == name) {
        v = item;
        break;
      }
    }
    if (v == null) return;
    await _speaker.engine.setVoice({
      'name': name,
      'locale': (v['locale'] ?? '').toString(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(voicePrefKey(appLang), name);
    if (mounted) setState(() => _voiceName = name);
    await _speaker.speak(appStrings.voiceSample);
  }

  Future<void> _openVoicePicker() async {
    if (_voices.isEmpty) {
      await _setupVoice();
    }
    if (!mounted) return;
    final t = stringsFor(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final names =
                _voices.map((v) => (v['name'] ?? '').toString()).toList();
            final safeValue = names.contains(_voiceName) ? _voiceName : null;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.chooseVoice,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_voices.isEmpty)
                      Text(t.noVoices)
                    else
                      DropdownButton<String>(
                        isExpanded: true,
                        value: safeValue,
                        hint: Text(t.pickAVoice),
                        items: names
                            .map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (name) {
                          if (name != null) {
                            _selectVoice(name);
                            setSheetState(() {});
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    Text(
                      t.voiceTip,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();
    try {
      final reply = await askTutor(context: _context, messages: _messages);
      if (!mounted) return;
      setState(() => _messages.add({'role': 'model', 'text': reply}));
      if (_speakAloud) {
        await _speaker.speak(reply);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({'role': 'model', 'text': e.toString()}));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize();
    if (!ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appStrings.voiceNotAvailable),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: appLang == 'ar' ? 'ar-SA' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    final greeting = t.chatGreeting(widget.lessonSet.sourceName);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.askTutor),
        actions: [
          // Arabic uses the automatic online voice, so the device-voice
          // picker is only useful for English.
          if (appLang == 'en')
            IconButton(
              tooltip: t.chooseVoice,
              icon: const Icon(Icons.record_voice_over),
              onPressed: _openVoicePicker,
            ),
          IconButton(
            tooltip: _speakAloud ? t.voiceAnswersOn : t.voiceAnswersOff,
            icon: Icon(_speakAloud ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              setState(() => _speakAloud = !_speakAloud);
              await setSpeakAloud(_speakAloud);
              if (!_speakAloud) await _speaker.stop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _Bubble(text: greeting, isUser: false);
                }
                final m = _messages[i - 1];
                return _Bubble(
                  text: m['text'] ?? '',
                  isUser: m['role'] == 'user',
                );
              },
            ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t.tutorThinking,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _toggleListen,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    color: _listening ? theme.colorScheme.error : null,
                    tooltip: t.speakYourQuestion,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: t.askQuestionHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _Bubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
