// Firebase project settings for this app.
//
// These values are SAFE to keep in the code: the web apiKey only IDENTIFIES
// the project - it does not grant access. Real protection comes from the
// Firestore security rules (a logged-in user can only read/write their own
// lessons) set in the Firebase console.
//
// The app only runs on the web, so we always return the web settings.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDoS-8P00Oa0NdC7s_WjHuf47vztELDmUc',
    appId: '1:784821661471:web:00fa3cc1ed780460f58a2a',
    messagingSenderId: '784821661471',
    projectId: 'ai-tutor-6237f',
    authDomain: 'ai-tutor-6237f.firebaseapp.com',
    storageBucket: 'ai-tutor-6237f.firebasestorage.app',
    measurementId: 'G-DTVN2ZNDNW',
  );
}
