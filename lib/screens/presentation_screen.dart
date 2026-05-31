import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../i18n.dart';
import '../services/ask_service.dart';
import '../services/narration_service.dart';
import '../services/speaker.dart';
import '../services/voice.dart';

class PresentationScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;
  const PresentationScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
  });

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  final PageController _pageController = PageController();
  final Speaker _speaker = Speaker();
  final List<Uint8List> _pages = [];
  List<String> _narrations = [];

  bool _loading = true; // rasterizing slides
  bool _narrationLoading = false;
  String? _error;
  String? _narrationError;
  bool _playing = false;
  bool _programmatic = false;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _speaker.setCompletionHandler(_onSpeakDone);
    _speaker.init();
    _loadPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _speaker.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    try {
      // 96 dpi matches a normal screen, so slides stay crisp but render
      // noticeably faster (fewer pixels) than the old 110.
      await for (final page in Printing.raster(widget.pdfBytes, dpi: 96)) {
        final png = await page.toPng();
        if (!mounted) return;
        setState(() => _pages.add(png));
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_pages.isEmpty) _error = appStrings.noSlides;
      });
      if (_pages.isNotEmpty) _loadNarrations();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = appStrings.couldNotOpenSlides;
        });
      }
    }
  }

  Future<void> _loadNarrations() async {
    setState(() {
      _narrationLoading = true;
      _narrationError = null;
    });
    try {
      final list = await fetchNarrations(
        pdfBytes: widget.pdfBytes,
        slideCount: _pages.length,
      );
      if (!mounted) return;
      setState(() {
        _narrations = list;
        _narrationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _narrationError = e.toString();
        _narrationLoading = false;
      });
    }
  }

  String _textFor(int i) {
    if (i >= 0 && i < _narrations.length && _narrations[i].trim().isNotEmpty) {
      return _narrations[i];
    }
    return appStrings.slideFallback(i + 1);
  }

  // Called by the TTS engine when a slide's narration finishes.
  void _onSpeakDone() {
    if (!mounted || !_playing) return;
    if (_current < _pages.length - 1) {
      final next = _current + 1;
      _programmatic = true;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _current = next);
      _speaker.speak(_textFor(next));
    } else {
      setState(() => _playing = false);
    }
  }

  Future<void> _togglePlay() async {
    if (_narrations.isEmpty) {
      await _loadNarrations();
      if (_narrations.isEmpty) return;
    }
    if (_playing) {
      setState(() => _playing = false);
      await _speaker.stop();
    } else {
      setState(() => _playing = true);
      await _speaker.speak(_textFor(_current));
    }
  }

  // Pauses the lecture and opens the "ask about this slide" sheet.
  Future<void> _raiseHand() async {
    if (_playing) setState(() => _playing = false);
    await _speaker.stop();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AskSheet(
        pdfBytes: widget.pdfBytes,
        slideNumber: _current + 1,
        speaker: _speaker,
      ),
    );
    // Stop any answer that may still be playing when the sheet closes.
    await _speaker.stop();
  }

  Future<void> _goManual(int target) async {
    if (target < 0 || target >= _pages.length) return;
    setState(() => _playing = false);
    await _speaker.stop();
    _programmatic = true;
    await _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _current = i);
    if (_programmatic) {
      _programmatic = false;
    } else if (_playing) {
      // User swiped manually while playing -> pause.
      setState(() => _playing = false);
      _speaker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(Theme.of(context)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final t = stringsFor(context);
    if (_loading && _pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(t.openingSlides),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_narrationLoading)
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.preparingLecture,
                    style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        if (_narrationError != null)
          Container(
            width: double.infinity,
            color: theme.colorScheme.errorContainer,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _narrationError!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: _loadNarrations,
                  child: Text(t.retry),
                ),
              ],
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) {
              return InteractiveViewer(
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(child: Image.memory(_pages[i])),
                ),
              );
            },
          ),
        ),
        if (_narrations.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 110),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              child: Text(_textFor(_current), style: theme.textTheme.bodyMedium),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.slideXofY(_current + 1, _pages.length),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _current > 0 ? () => _goManual(_current - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _narrationLoading ? null : _togglePlay,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        label: Text(_playing ? t.pause : t.playLecture),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _current < _pages.length - 1
                          ? () => _goManual(_current + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _raiseHand,
                    icon: const Icon(Icons.front_hand),
                    label: Text(t.raiseHand),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Bottom sheet that lets the student ask a question about the current slide,
// by typing or by speaking. The answer is shown and read out loud.
class _AskSheet extends StatefulWidget {
  final Uint8List pdfBytes;
  final int slideNumber; // 1-based
  final Speaker speaker;
  const _AskSheet({
    required this.pdfBytes,
    required this.slideNumber,
    required this.speaker,
  });

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _controller = TextEditingController();

  bool _speechAvailable = false;
  bool _listening = false;
  bool _thinking = false;
  String? _answer;
  String? _error;

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = appStrings.couldNotHear;
            });
          }
        },
      );
    }
    if (!_speechAvailable) {
      setState(() {
        _error = appStrings.voiceInputNotHere;
      });
      return;
    }
    setState(() {
      _error = null;
      _listening = true;
    });
    await _speech.listen(
      onResult: (result) {
        // Ignore stray results that arrive after we stop or after sending.
        if (!mounted || !_listening) return;
        // Clean every update: on the web the recognizer restarts mid-listen and
        // stacks the phrase up over and over. Also stop as soon as it is final.
        setState(() =>
            _controller.text = collapseRepeatedSpeech(result.recognizedWords));
        if (result.finalResult) {
          _speech.stop();
          setState(() => _listening = false);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: appLang == 'ar' ? 'ar-SA' : null,
      ),
    );
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    await _speech.stop();
    await widget.speaker.stop();
    setState(() {
      _listening = false;
      _thinking = true;
      _answer = null;
      _error = null;
    });
    try {
      final answer = await askAboutSlide(
        pdfBytes: widget.pdfBytes,
        slideNumber: widget.slideNumber,
        question: question,
      );
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _thinking = false;
      });
      await widget.speaker.speak(answer);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _thinking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.front_hand, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  t.askAboutSlide(widget.slideNumber),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: t.askSheetHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _thinking ? null : _toggleListen,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? t.listening : t.talk),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _thinking ? null : _send,
                    icon: const Icon(Icons.send),
                    label: Text(t.ask),
                  ),
                ),
              ],
            ),
            if (_thinking) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(t.thinking),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _answer!,
                  style:
                      TextStyle(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => widget.speaker.speak(_answer!),
                    icon: const Icon(Icons.volume_up),
                    label: Text(t.hearAgain),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      widget.speaker.stop();
                      _controller.clear();
                      setState(() => _answer = null);
                    },
                    child: Text(t.askAnother),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  widget.speaker.stop();
                  Navigator.of(context).pop();
                },
                child: Text(t.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
