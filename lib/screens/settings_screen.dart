import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';
import '../services/speaker.dart';
import '../services/voice.dart';

// One place for language, the spoken voice, and the "read aloud" choice.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Speaker _speaker = Speaker();

  List<Map> _voices = [];
  String? _voiceName;
  bool _speakAloud = false;
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    // Reload the voice list whenever the language changes.
    localeNotifier.addListener(_onLocaleChanged);
    _load();
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    _speaker.dispose();
    super.dispose();
  }

  void _onLocaleChanged() => _loadVoices();

  Future<void> _load() async {
    _speakAloud = await getSpeakAloud();
    if (mounted) setState(() {});
    await _loadVoices();
  }

  Future<void> _loadVoices() async {
    if (mounted) setState(() => _loadingVoices = true);
    await _speaker.engine.setLanguage(appLang == 'ar' ? 'ar-SA' : 'en-US');
    final list = await voicesForLang(_speaker.engine, appLang);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(voicePrefKey(appLang));
    String? current;
    if (saved != null &&
        list.any((v) => (v['name'] ?? '').toString() == saved)) {
      current = saved;
    }
    if (mounted) {
      setState(() {
        _voices = list;
        _voiceName = current;
        _loadingVoices = false;
      });
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
    // Speak a short sample so the user hears the new voice.
    await _speaker.speak(appStrings.voiceSample);
  }

  Widget _languageTile(String code, String label) {
    final theme = Theme.of(context);
    final selected = appLang == code;
    return ListTile(
      leading: Icon(
        selected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
      onTap: () => setLocale(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    final names = _voices.map((v) => (v['name'] ?? '').toString()).toList();
    final safeValue = names.contains(_voiceName) ? _voiceName : null;
    final isArabic = appLang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionTitle(t.settingsLanguageSection),
          _languageTile('en', 'English'),
          _languageTile('ar', 'العربية'),
          const Divider(height: 24),
          _SectionTitle(t.settingsVoiceSection),
          SwitchListTile(
            value: _speakAloud,
            onChanged: (v) async {
              await setSpeakAloud(v);
              if (mounted) setState(() => _speakAloud = v);
            },
            title: Text(t.readAnswersAloud),
            subtitle: Text(t.readAnswersAloudHint),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: isArabic
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NoteBox(
                        text: t.arabicVoiceNote,
                        bg: theme.colorScheme.primaryContainer,
                        fg: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _speaker.speak(appStrings.voiceSample),
                          icon: const Icon(Icons.volume_up),
                          label: Text(t.hearVoiceSample),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.chooseVoice,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            tooltip: t.retry,
                            icon: _loadingVoices
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                            onPressed: _loadingVoices ? null : _loadVoices,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_loadingVoices)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_voices.isEmpty)
                        Text(t.noVoices, style: theme.textTheme.bodyMedium)
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
                            if (name != null) _selectVoice(name);
                          },
                        ),
                      const SizedBox(height: 12),
                      Text(
                        t.voiceTip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _NoteBox({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
