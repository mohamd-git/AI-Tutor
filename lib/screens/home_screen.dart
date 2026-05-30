import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models/lesson.dart';
import '../sample_data.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../services/lesson_store.dart';
import 'auth_screen.dart';
import 'lesson_screen.dart';
import 'presentation_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _pickedName;
  Uint8List? _pickedBytes;
  bool _isGenerating = false;
  List<SavedLesson> _saved = [];
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    _refreshSaved();
    // Reload (and rebuild the app bar/banner) whenever the user signs in or
    // out - the lesson list then comes from the cloud or the device to match.
    _authSub = authChanges().listen((_) {
      if (mounted) _refreshSaved();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshSaved() async {
    final saved = await loadLessons();
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _openAuth() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    // The auth-change listener refreshes the list automatically on return.
  }

  Future<void> _signOut() async {
    await signOut();
    if (!mounted) return;
    _showMessage(appStrings.signedOutSnack);
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return; // user cancelled
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showMessage(appStrings.couldNotReadFile);
        return;
      }
      setState(() {
        _pickedName = file.name;
        _pickedBytes = bytes;
      });
    } catch (_) {
      _showMessage(appStrings.fileChooseError);
    }
  }

  Future<void> _generate() async {
    final bytes = _pickedBytes;
    if (bytes == null) return;
    setState(() => _isGenerating = true);
    try {
      final lessonSet = await generateLesson(
        pdfBytes: bytes,
        fileName: _pickedName ?? 'Your slides',
      );
      await saveLesson(lessonSet);
      await _refreshSaved();
      if (!mounted) return;
      _openLesson(lessonSet);
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openLesson(LessonSet lessonSet) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonScreen(lessonSet: lessonSet)),
    );
  }

  void _present() {
    final bytes = _pickedBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresentationScreen(
          pdfBytes: bytes,
          title: _pickedName ?? 'Slides',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final t = stringsFor(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteTitle),
        content: Text(t.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteLesson(id);
      await _refreshSaved();
      _showMessage(appStrings.lessonDeleted);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Guest -> a "Sign in" button. Signed in -> a menu showing the email with a
  // "Sign out" option.
  Widget _accountAction(Strings t) {
    if (!isSignedIn) {
      return IconButton(
        tooltip: t.signIn,
        icon: const Icon(Icons.login),
        onPressed: _openAuth,
      );
    }
    return PopupMenuButton<String>(
      tooltip: t.accountTooltip,
      icon: const Icon(Icons.account_circle),
      onSelected: (v) {
        if (v == 'signout') _signOut();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            currentEmail ?? '',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20),
              const SizedBox(width: 12),
              Text(t.signOut),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        centerTitle: true,
        actions: [
          _accountAction(t),
          IconButton(
            tooltip: t.settingsTooltip,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.auto_stories,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                t.homeHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                t.homeSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (!isSignedIn) ...[
                const SizedBox(height: 20),
                _GuestBanner(onSignIn: _openAuth),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isGenerating ? null : _pickPdf,
                icon: const Icon(Icons.upload_file),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.uploadButton),
                ),
              ),
              if (_pickedBytes != null) ...[
                const SizedBox(height: 16),
                _SelectedFileCard(
                  name: _pickedName ?? 'your file.pdf',
                  sizeLabel: _formatSize(_pickedBytes!.length),
                  isLoading: _isGenerating,
                  onGenerate: _generate,
                ),
                if (!_isGenerating) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _present,
                      icon: const Icon(Icons.slideshow),
                      label: Text(t.startLecture),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              Text(
                t.yourLessons,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _saved.length; i++)
                _LessonCard(
                  lessonSet: _saved[i].lesson,
                  onTap: () => _openLesson(_saved[i].lesson),
                  onDelete: () => _confirmDelete(_saved[i].id),
                ),
              _LessonCard(
                lessonSet: sampleLessonSet,
                onTap: () => _openLesson(sampleLessonSet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFileCard extends StatelessWidget {
  final String name;
  final String sizeLabel;
  final bool isLoading;
  final VoidCallback onGenerate;
  const _SelectedFileCard({
    required this.name,
    required this.sizeLabel,
    required this.isLoading,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        sizeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.generatingMsg,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(t.generateLesson),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final LessonSet lessonSet;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _LessonCard({
    required this.lessonSet,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.menu_book,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(lessonSet.sourceName),
        subtitle: Text(t.topicsCount(lessonSet.topics.length)),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: t.delete,
                onPressed: onDelete,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// Shown only to guests: a gentle reminder that lessons live on this device
// only, with a button to sign in and keep them on an account.
class _GuestBanner extends StatelessWidget {
  final VoidCallback onSignIn;
  const _GuestBanner({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.guestBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.guestBannerBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login, size: 18),
                label: Text(t.signIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
