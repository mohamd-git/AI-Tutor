import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'i18n.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Firebase (sign-in + cloud-saved lessons). If it ever fails, the
  // app still opens in guest mode using device storage.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Keep going as a guest-only app rather than showing a blank screen.
  }
  await loadSavedLocale();
  runApp(const SlideTutorApp());
}

class SlideTutorApp extends StatelessWidget {
  const SlideTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app whenever the language changes. Flutter flips the
    // layout to right-to-left automatically when the locale is Arabic.
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'Slide Tutor',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
