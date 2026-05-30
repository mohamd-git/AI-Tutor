// Talks to Firebase Authentication so the user never handles raw passwords -
// Firebase stores and checks them securely. We only ask for an email and a
// password and call these small helpers.

import 'package:firebase_auth/firebase_auth.dart';

import '../i18n.dart';

// Who is signed in right now (null = nobody, i.e. a guest). Wrapped in a
// try/catch so that, if Firebase failed to start up, the app simply behaves
// as a guest instead of crashing.
User? get currentUser {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

// True when someone is signed in. Used by the lesson store to decide whether
// to save to the cloud or to this device.
bool get isSignedIn => currentUser != null;

// The signed-in user's id (used as their private folder in the database).
String? get currentUid => currentUser?.uid;

// The signed-in user's email, for showing in the app bar menu.
String? get currentEmail => currentUser?.email;

// Fires whenever the user signs in or out, so the home screen can refresh.
Stream<User?> authChanges() {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return const Stream<User?>.empty();
  }
}

// Creates a brand-new account, then signs them in automatically.
Future<void> signUp(String email, String password) async {
  await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );
}

// Signs an existing user in.
Future<void> signIn(String email, String password) async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );
}

// Signs the current user out (back to guest mode).
Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
}

// Turns a raw Firebase error into a short, friendly message in the app's
// current language. Anything we do not recognise becomes a generic message.
String friendlyAuthError(Object error, Strings t) {
  if (error is FirebaseAuthException) return t.authError(error.code);
  return t.genericTryAgain;
}
