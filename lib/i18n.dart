import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Language state
//
// The whole app listens to [localeNotifier]. Flipping it (via [toggleLocale])
// rebuilds the app, switches every string, and flips the layout to
// right-to-left for Arabic. The choice is saved on the device.
// ---------------------------------------------------------------------------

const String _prefKey = 'app_lang';

final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(
  const Locale('en'),
);

// Short language code ('en' or 'ar') for non-widget code (the services).
String get appLang => localeNotifier.value.languageCode;

// Loads the saved language at startup. Call before runApp.
Future<void> loadSavedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == 'ar' || code == 'en') {
      localeNotifier.value = Locale(code!);
    }
  } catch (_) {
    // Keep the default (English) if reading fails.
  }
}

// Switches between English and Arabic and remembers the choice.
Future<void> toggleLocale() async {
  final next = appLang == 'ar' ? const Locale('en') : const Locale('ar');
  await setLocale(next.languageCode);
}

// Sets a specific language ('en' or 'ar') and remembers the choice. Used by
// the Settings screen.
Future<void> setLocale(String code) async {
  if (code != 'ar' && code != 'en') return;
  localeNotifier.value = Locale(code);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  } catch (_) {
    // Saving is best-effort.
  }
}

// Strings for widgets. Depends on Localizations, so widgets that call this
// rebuild automatically when the language changes.
Strings stringsFor(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar' ? _ar : _en;

// Strings for code that has no BuildContext (the network services).
Strings get appStrings => appLang == 'ar' ? _ar : _en;

// ---------------------------------------------------------------------------
// The language toggle button (used in the app bars)
// ---------------------------------------------------------------------------

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return TextButton.icon(
      onPressed: () => toggleLocale(),
      icon: const Icon(Icons.translate, size: 20),
      label: Text(isArabic ? 'English' : 'العربية'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Every user-facing string, in both languages.
// ---------------------------------------------------------------------------

class Strings {
  final String code; // 'en' or 'ar'

  // Home
  final String appTitle;
  final String homeHeadline;
  final String homeSubtitle;
  final String uploadButton;
  final String startLecture;
  final String yourLessons;
  final String generateLesson;
  final String generatingMsg;
  final String deleteTitle;
  final String deleteBody;
  final String cancel;
  final String delete;
  final String lessonDeleted;
  final String couldNotReadFile;
  final String fileChooseError;

  // Lesson
  final String askTutor;
  final String keyWords;
  final String formulas;
  final String quickCheck;
  final String watchYoutube;
  final String tryAgain;
  final String correctPrefix;
  final String notQuitePrefix;

  // Chat
  final String chooseVoice;
  final String pickAVoice;
  final String noVoices;
  final String voiceTip;
  final String tutorThinking;
  final String askQuestionHint;
  final String voiceAnswersOn;
  final String voiceAnswersOff;
  final String speakYourQuestion;
  final String voiceNotAvailable;
  final String voiceSample;

  // Settings
  final String settingsTitle;
  final String settingsTooltip;
  final String settingsLanguageSection;
  final String settingsVoiceSection;
  final String readAnswersAloud;
  final String readAnswersAloudHint;
  final String arabicVoiceNote;
  final String hearVoiceSample;

  // Presentation / lecture
  final String openingSlides;
  final String noSlides;
  final String couldNotOpenSlides;
  final String preparingLecture;
  final String retry;
  final String pause;
  final String playLecture;
  final String raiseHand;
  final String askSheetHint;
  final String talk;
  final String listening;
  final String ask;
  final String thinking;
  final String hearAgain;
  final String askAnother;
  final String close;
  final String couldNotHear;
  final String voiceInputNotHere;

  // Service / network errors
  final String couldNotReachHelper;
  final String couldNotReachHelperLong;
  final String makeLessonError;
  final String lessonReadError;
  final String noTopics;
  final String pdfTooLargeOnline;
  final String genericTryAgain;
  final String couldNotReadAnswer;
  final String tutorEmpty;
  final String tutorNoAnswer;
  final String answerQuestionError;
  final String prepareLectureError;
  final String readLectureError;

  // Account / sign-in
  final String accountTooltip;
  final String signIn;
  final String signUp;
  final String signOut;
  final String emailLabel;
  final String passwordLabel;
  final String signInTitle;
  final String signUpTitle;
  final String signInSubtitle;
  final String signUpSubtitle;
  final String toggleToSignIn;
  final String toggleToSignUp;
  final String continueAsGuest;
  final String guestBannerTitle;
  final String guestBannerBody;
  final String needEmailPassword;
  final String passwordTooShort;
  final String signedOutSnack;

  const Strings({
    required this.code,
    required this.appTitle,
    required this.homeHeadline,
    required this.homeSubtitle,
    required this.uploadButton,
    required this.startLecture,
    required this.yourLessons,
    required this.generateLesson,
    required this.generatingMsg,
    required this.deleteTitle,
    required this.deleteBody,
    required this.cancel,
    required this.delete,
    required this.lessonDeleted,
    required this.couldNotReadFile,
    required this.fileChooseError,
    required this.askTutor,
    required this.keyWords,
    required this.formulas,
    required this.quickCheck,
    required this.watchYoutube,
    required this.tryAgain,
    required this.correctPrefix,
    required this.notQuitePrefix,
    required this.chooseVoice,
    required this.pickAVoice,
    required this.noVoices,
    required this.voiceTip,
    required this.tutorThinking,
    required this.askQuestionHint,
    required this.voiceAnswersOn,
    required this.voiceAnswersOff,
    required this.speakYourQuestion,
    required this.voiceNotAvailable,
    required this.voiceSample,
    required this.settingsTitle,
    required this.settingsTooltip,
    required this.settingsLanguageSection,
    required this.settingsVoiceSection,
    required this.readAnswersAloud,
    required this.readAnswersAloudHint,
    required this.arabicVoiceNote,
    required this.hearVoiceSample,
    required this.openingSlides,
    required this.noSlides,
    required this.couldNotOpenSlides,
    required this.preparingLecture,
    required this.retry,
    required this.pause,
    required this.playLecture,
    required this.raiseHand,
    required this.askSheetHint,
    required this.talk,
    required this.listening,
    required this.ask,
    required this.thinking,
    required this.hearAgain,
    required this.askAnother,
    required this.close,
    required this.couldNotHear,
    required this.voiceInputNotHere,
    required this.couldNotReachHelper,
    required this.couldNotReachHelperLong,
    required this.makeLessonError,
    required this.lessonReadError,
    required this.noTopics,
    required this.pdfTooLargeOnline,
    required this.genericTryAgain,
    required this.couldNotReadAnswer,
    required this.tutorEmpty,
    required this.tutorNoAnswer,
    required this.answerQuestionError,
    required this.prepareLectureError,
    required this.readLectureError,
    required this.accountTooltip,
    required this.signIn,
    required this.signUp,
    required this.signOut,
    required this.emailLabel,
    required this.passwordLabel,
    required this.signInTitle,
    required this.signUpTitle,
    required this.signInSubtitle,
    required this.signUpSubtitle,
    required this.toggleToSignIn,
    required this.toggleToSignUp,
    required this.continueAsGuest,
    required this.guestBannerTitle,
    required this.guestBannerBody,
    required this.needEmailPassword,
    required this.passwordTooShort,
    required this.signedOutSnack,
  });

  // Strings that include a number or name.
  String topicsCount(int n) => code == 'ar' ? '$n مواضيع' : '$n topics';

  String chatGreeting(String name) => code == 'ar'
      ? 'مرحباً! اسألني أي شيء عن «$name». سأشرح بكلمات بسيطة.'
      : 'Hi! Ask me anything about "$name". I will explain in simple words.';

  String slideXofY(int a, int b) =>
      code == 'ar' ? 'الشريحة $a من $b' : 'Slide $a of $b';

  String askAboutSlide(int n) =>
      code == 'ar' ? 'اسأل عن الشريحة $n' : 'Ask about slide $n';

  String slideFallback(int n) =>
      code == 'ar' ? 'لننظر إلى الشريحة $n.' : 'Let us look at slide $n.';

  String signedInSnack(String email) =>
      code == 'ar' ? 'تم تسجيل الدخول باسم $email' : 'Signed in as $email';

  String movedLessons(int n) => code == 'ar'
      ? 'تم نقل $n من الدروس إلى حسابك.'
      : 'Moved $n ${n == 1 ? 'lesson' : 'lessons'} to your account.';

  // Turns a Firebase error code into a short, friendly message. The parameter
  // [errorCode] is the Firebase code; [code] (the field) is the app language.
  String authError(String errorCode) {
    final ar = code == 'ar';
    switch (errorCode) {
      case 'invalid-email':
        return ar
            ? 'البريد الإلكتروني غير صالح.'
            : 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return ar
            ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
            : 'Wrong email or password.';
      case 'email-already-in-use':
        return ar
            ? 'هذا البريد لديه حساب بالفعل. جرّب تسجيل الدخول.'
            : 'That email already has an account. Try signing in.';
      case 'weak-password':
        return ar
            ? 'كلمة المرور ضعيفة جداً (٦ أحرف على الأقل).'
            : 'That password is too weak (use at least 6 characters).';
      case 'network-request-failed':
        return ar
            ? 'لا يوجد اتصال بالإنترنت. تحقّق من شبكتك.'
            : 'No internet connection. Check your network.';
      case 'too-many-requests':
        return ar
            ? 'محاولات كثيرة جداً. حاول لاحقاً.'
            : 'Too many attempts. Please try again later.';
      default:
        return ar
            ? 'حدث خطأ ما. حاول مرة أخرى.'
            : 'Something went wrong. Please try again.';
    }
  }
}

const Strings _en = Strings(
  code: 'en',
  appTitle: 'Slide Tutor',
  homeHeadline: 'Turn your slides into an easy lesson',
  homeSubtitle: 'Choose a PDF of your class slides. We break it into topics '
      'and teach each one in simple words.',
  uploadButton: 'Upload your slides (PDF)',
  startLecture: 'Start AI Lecture',
  yourLessons: 'Your lessons',
  generateLesson: 'Generate lesson',
  generatingMsg: 'Reading your slides and writing your lesson... '
      'this can take 20-45 seconds.',
  deleteTitle: 'Delete lesson?',
  deleteBody: 'This removes the saved lesson from this device.',
  cancel: 'Cancel',
  delete: 'Delete',
  lessonDeleted: 'Lesson deleted.',
  couldNotReadFile: 'Could not read that file. Please try another PDF.',
  fileChooseError:
      'Something went wrong choosing the file. Please try again.',
  askTutor: 'Ask the tutor',
  keyWords: 'Key words',
  formulas: 'Formulas',
  quickCheck: 'Quick check',
  watchYoutube: 'Still stuck? Watch on YouTube',
  tryAgain: 'Try again',
  correctPrefix: 'Correct! ',
  notQuitePrefix: 'Not quite. ',
  chooseVoice: 'Choose voice',
  pickAVoice: 'Pick a voice',
  noVoices: 'No voices found in this browser.',
  voiceTip: 'Tip: Microsoft Edge usually has more natural ("Natural") '
      'voices than Chrome on Windows. Open the same address in '
      'Edge for a more human voice.',
  tutorThinking: 'Tutor is thinking...',
  askQuestionHint: 'Ask a question...',
  voiceAnswersOn: 'Voice answers: on',
  voiceAnswersOff: 'Voice answers: off',
  speakYourQuestion: 'Speak your question',
  voiceNotAvailable: 'Voice input is not available in this browser.',
  voiceSample:
      'Hi! This is how I sound. I will explain your lessons in simple words.',
  settingsTitle: 'Settings',
  settingsTooltip: 'Settings',
  settingsLanguageSection: 'Language',
  settingsVoiceSection: 'Voice',
  readAnswersAloud: 'Read AI answers aloud',
  readAnswersAloudHint: 'When on, the tutor speaks its chat answers out loud.',
  arabicVoiceNote:
      'Arabic is read aloud with a clear online voice, so it works in any '
      'browser with nothing to download. Just keep the helper running and '
      'stay connected to the internet.',
  hearVoiceSample: 'Hear a sample',
  openingSlides: 'Opening your slides...',
  noSlides: 'No slides could be read from this PDF.',
  couldNotOpenSlides: 'Could not open the slides. Please try another PDF.',
  preparingLecture: 'Preparing the AI lecture...',
  retry: 'Retry',
  pause: 'Pause',
  playLecture: 'Play lecture',
  raiseHand: 'Raise your hand to ask',
  askSheetHint: 'Type your question, or tap Talk to speak',
  talk: 'Talk',
  listening: 'Listening...',
  ask: 'Ask',
  thinking: 'Thinking...',
  hearAgain: 'Hear again',
  askAnother: 'Ask another',
  close: 'Close',
  couldNotHear:
      'I could not hear you. You can type your question instead.',
  voiceInputNotHere:
      'Voice input is not available here. Please type your question.',
  couldNotReachHelper:
      'Could not reach the helper. Make sure it is running, then try again.',
  couldNotReachHelperLong:
      'Could not reach the helper. Make sure it is running '
      '(dart run server/dev_server.dart in a terminal), then try again.',
  makeLessonError: 'Something went wrong making the lesson.',
  lessonReadError:
      'The AI sent back something we could not read. Please try again.',
  noTopics: 'The AI could not find topics in that PDF. Try another file.',
  pdfTooLargeOnline:
      'This PDF is a bit too large for the online version (about 3 MB max). '
      'Try a smaller PDF, or run the app on your computer for large files.',
  genericTryAgain: 'Something went wrong. Please try again.',
  couldNotReadAnswer: 'Could not read the answer. Please try again.',
  tutorEmpty: 'The tutor sent an empty answer. Please try again.',
  tutorNoAnswer: 'The tutor did not have an answer. Please try again.',
  answerQuestionError: 'Could not answer the question.',
  prepareLectureError: 'Could not prepare the lecture.',
  readLectureError: 'Could not read the lecture. Please try again.',
  accountTooltip: 'Account',
  signIn: 'Sign in',
  signUp: 'Create account',
  signOut: 'Sign out',
  emailLabel: 'Email',
  passwordLabel: 'Password',
  signInTitle: 'Welcome back',
  signUpTitle: 'Create your account',
  signInSubtitle: 'Sign in to keep your lessons on every device.',
  signUpSubtitle: 'Your saved lessons will follow you to any device.',
  toggleToSignIn: 'Already have an account? Sign in',
  toggleToSignUp: 'New here? Create an account',
  continueAsGuest: 'Continue as guest',
  guestBannerTitle: "You're a guest",
  guestBannerBody: 'Lessons are saved on this device only. '
      'Sign in to keep them on your account.',
  needEmailPassword: 'Please enter your email and password.',
  passwordTooShort: 'Password must be at least 6 characters.',
  signedOutSnack: 'Signed out.',
);

const Strings _ar = Strings(
  code: 'ar',
  appTitle: 'معلّم الشرائح',
  homeHeadline: 'حوّل شرائحك إلى درس سهل',
  homeSubtitle: 'اختر ملف PDF لشرائح حصتك. سنقسّمه إلى مواضيع '
      'ونشرح كل موضوع بكلمات بسيطة.',
  uploadButton: 'ارفع شرائحك (PDF)',
  startLecture: 'ابدأ محاضرة الذكاء الاصطناعي',
  yourLessons: 'دروسك',
  generateLesson: 'أنشئ الدرس',
  generatingMsg: 'نقرأ شرائحك ونكتب درسك... '
      'قد يستغرق هذا من ٢٠ إلى ٤٥ ثانية.',
  deleteTitle: 'حذف الدرس؟',
  deleteBody: 'سيؤدي هذا إلى إزالة الدرس المحفوظ من هذا الجهاز.',
  cancel: 'إلغاء',
  delete: 'حذف',
  lessonDeleted: 'تم حذف الدرس.',
  couldNotReadFile: 'تعذّرت قراءة هذا الملف. جرّب ملف PDF آخر.',
  fileChooseError: 'حدث خطأ أثناء اختيار الملف. حاول مرة أخرى.',
  askTutor: 'اسأل المعلّم',
  keyWords: 'كلمات مهمة',
  formulas: 'معادلات',
  quickCheck: 'اختبار سريع',
  watchYoutube: 'ما زلت غير فاهم؟ شاهد على يوتيوب',
  tryAgain: 'حاول مرة أخرى',
  correctPrefix: 'صحيح! ',
  notQuitePrefix: 'ليس تماماً. ',
  chooseVoice: 'اختر الصوت',
  pickAVoice: 'اختر صوتاً',
  noVoices: 'لا توجد أصوات في هذا المتصفح.',
  voiceTip: 'نصيحة: غالباً ما يوفّر متصفح Microsoft Edge أصواتاً أكثر '
      'طبيعية من Chrome على ويندوز. افتح العنوان نفسه في Edge '
      'للحصول على صوت أقرب للبشري.',
  tutorThinking: 'المعلّم يفكّر...',
  askQuestionHint: 'اطرح سؤالاً...',
  voiceAnswersOn: 'الإجابات الصوتية: مفعّلة',
  voiceAnswersOff: 'الإجابات الصوتية: متوقفة',
  speakYourQuestion: 'انطق سؤالك',
  voiceNotAvailable: 'الإدخال الصوتي غير متاح في هذا المتصفح.',
  voiceSample: 'مرحباً! هكذا أبدو. سأشرح دروسك بكلمات بسيطة.',
  settingsTitle: 'الإعدادات',
  settingsTooltip: 'الإعدادات',
  settingsLanguageSection: 'اللغة',
  settingsVoiceSection: 'الصوت',
  readAnswersAloud: 'قراءة إجابات الذكاء الاصطناعي بصوت عالٍ',
  readAnswersAloudHint: 'عند التفعيل، ينطق المعلّم إجاباته في المحادثة بصوت عالٍ.',
  arabicVoiceNote:
      'تُقرأ العربية بصوت عربي واضح عبر الإنترنت، لذا تعمل في أي متصفح دون أي '
      'تنزيلات. فقط أبقِ المساعد قيد التشغيل وابقَ متصلاً بالإنترنت.',
  hearVoiceSample: 'استمع إلى عيّنة',
  openingSlides: 'نفتح شرائحك...',
  noSlides: 'تعذّرت قراءة أي شرائح من ملف PDF هذا.',
  couldNotOpenSlides: 'تعذّر فتح الشرائح. جرّب ملف PDF آخر.',
  preparingLecture: 'نُحضّر محاضرة الذكاء الاصطناعي...',
  retry: 'إعادة المحاولة',
  pause: 'إيقاف مؤقت',
  playLecture: 'تشغيل المحاضرة',
  raiseHand: 'ارفع يدك لتسأل',
  askSheetHint: 'اكتب سؤالك، أو اضغط «تحدّث» لتنطقه',
  talk: 'تحدّث',
  listening: 'أستمع...',
  ask: 'اسأل',
  thinking: 'أفكّر...',
  hearAgain: 'استمع مرة أخرى',
  askAnother: 'اسأل سؤالاً آخر',
  close: 'إغلاق',
  couldNotHear: 'لم أتمكّن من سماعك. يمكنك كتابة سؤالك بدلاً من ذلك.',
  voiceInputNotHere: 'الإدخال الصوتي غير متاح هنا. اكتب سؤالك من فضلك.',
  couldNotReachHelper:
      'تعذّر الوصول إلى المساعد. تأكّد من أنه يعمل، ثم حاول مرة أخرى.',
  couldNotReachHelperLong: 'تعذّر الوصول إلى المساعد. تأكّد من أنه يعمل '
      '(شغّل dart run server/dev_server.dart في الطرفية)، ثم حاول مرة أخرى.',
  makeLessonError: 'حدث خطأ أثناء إنشاء الدرس.',
  lessonReadError: 'أرسل الذكاء الاصطناعي شيئاً تعذّرت قراءته. حاول مرة أخرى.',
  noTopics: 'لم يجد الذكاء الاصطناعي مواضيع في ملف PDF هذا. جرّب ملفاً آخر.',
  pdfTooLargeOnline:
      'هذا الملف كبير قليلاً على النسخة عبر الإنترنت (الحد الأقصى نحو ٣ ميغابايت). '
      'جرّب ملف PDF أصغر، أو شغّل التطبيق على حاسوبك للملفات الكبيرة.',
  genericTryAgain: 'حدث خطأ ما. حاول مرة أخرى.',
  couldNotReadAnswer: 'تعذّرت قراءة الإجابة. حاول مرة أخرى.',
  tutorEmpty: 'أرسل المعلّم إجابة فارغة. حاول مرة أخرى.',
  tutorNoAnswer: 'لم تكن لدى المعلّم إجابة. حاول مرة أخرى.',
  answerQuestionError: 'تعذّرت الإجابة عن السؤال.',
  prepareLectureError: 'تعذّر تحضير المحاضرة.',
  readLectureError: 'تعذّرت قراءة المحاضرة. حاول مرة أخرى.',
  accountTooltip: 'الحساب',
  signIn: 'تسجيل الدخول',
  signUp: 'إنشاء حساب',
  signOut: 'تسجيل الخروج',
  emailLabel: 'البريد الإلكتروني',
  passwordLabel: 'كلمة المرور',
  signInTitle: 'مرحباً بعودتك',
  signUpTitle: 'أنشئ حسابك',
  signInSubtitle: 'سجّل الدخول لتحتفظ بدروسك على كل الأجهزة.',
  signUpSubtitle: 'ستتبعك دروسك المحفوظة على أي جهاز.',
  toggleToSignIn: 'لديك حساب بالفعل؟ سجّل الدخول',
  toggleToSignUp: 'جديد هنا؟ أنشئ حساباً',
  continueAsGuest: 'المتابعة كضيف',
  guestBannerTitle: 'أنت تستخدم التطبيق كضيف',
  guestBannerBody: 'تُحفظ الدروس على هذا الجهاز فقط. '
      'سجّل الدخول للاحتفاظ بها في حسابك.',
  needEmailPassword: 'الرجاء إدخال بريدك الإلكتروني وكلمة المرور.',
  passwordTooShort: 'يجب ألا تقل كلمة المرور عن ٦ أحرف.',
  signedOutSnack: 'تم تسجيل الخروج.',
);
