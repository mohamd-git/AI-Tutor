import 'package:flutter/material.dart';

import '../i18n.dart';
import '../services/auth_service.dart';
import '../services/lesson_store.dart';

// One screen that handles BOTH signing in and creating an account - a link at
// the bottom flips between the two. Guests can also tap "Continue as guest" to
// back out and keep using the app without an account.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false; // false = sign in, true = create account
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = stringsFor(context);
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = t.needEmailPassword);
      return;
    }
    if (_isSignUp && password.length < 6) {
      setState(() => _error = t.passwordTooShort);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await signUp(email, password);
      } else {
        await signIn(email, password);
      }
      // Move any lessons saved while a guest into the new account.
      final moved = await uploadGuestLessonsToCloud();
      if (!mounted) return;
      // Grab these BEFORE popping - after pop this screen's context is gone,
      // but the app-level messenger/navigator stay valid.
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      navigator.pop(); // back to home, now signed in
      messenger.showSnackBar(SnackBar(content: Text(t.signedInSnack(email))));
      if (moved > 0) {
        messenger.showSnackBar(SnackBar(content: Text(t.movedLessons(moved))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e, t));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? t.signUp : t.signIn),
        centerTitle: true,
        actions: const [LanguageToggleButton(), SizedBox(width: 4)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Icon(Icons.account_circle,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                _isSignUp ? t.signUpTitle : t.signInTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? t.signUpSubtitle : t.signInSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: t.emailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: t.passwordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? t.signUp : t.signIn),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                        }),
                child: Text(_isSignUp ? t.toggleToSignIn : t.toggleToSignUp),
              ),
              const Divider(height: 32),
              TextButton.icon(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.person_outline),
                label: Text(t.continueAsGuest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
