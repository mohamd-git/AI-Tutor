import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lesson.dart';
import 'auth_service.dart';

// Saves lessons in TWO places, picked automatically:
//   * Signed in  -> the cloud (Firestore), so lessons follow the user to any
//                   device. Each user can only touch their own lessons.
//   * Guest      -> this device only (browser local storage), so lessons still
//                   survive a refresh even without an account.
//
// Every saved lesson carries a stable [id] so we can open or delete the right
// one. (The cloud needs real ids; we give device-saved lessons ids too so the
// screens work the same in both modes.)

// A saved lesson plus the id used to find, open, or delete it later.
class SavedLesson {
  final String id;
  final LessonSet lesson;
  const SavedLesson({required this.id, required this.lesson});
}

const String _key = 'saved_lessons_v1';

// ---------------------------------------------------------------------------
// Public API - the screens call these and never worry about where data lives.
// ---------------------------------------------------------------------------

Future<List<SavedLesson>> loadLessons() async {
  if (isSignedIn) return _cloudLoad();
  return _deviceLoad();
}

Future<SavedLesson> saveLesson(LessonSet lesson) async {
  if (isSignedIn) return _cloudSave(lesson);
  return _deviceSave(lesson);
}

Future<void> deleteLesson(String id) async {
  if (isSignedIn) return _cloudDelete(id);
  return _deviceDelete(id);
}

// When a guest signs in, copy any lessons saved on this device up to their
// cloud account so nothing is lost, then clear the device copy. Returns how
// many lessons moved (0 if none). Safe to call after every sign-in.
Future<int> uploadGuestLessonsToCloud() async {
  if (!isSignedIn) return 0;
  final onDevice = await _deviceLoad();
  if (onDevice.isEmpty) return 0;
  // Save oldest first so the newest ends up on top in the cloud list.
  for (final s in onDevice.reversed) {
    await _cloudSave(s.lesson);
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
  return onDevice.length;
}

// ---------------------------------------------------------------------------
// Cloud storage: users/{uid}/lessons/{lessonId}
// ---------------------------------------------------------------------------

CollectionReference<Map<String, dynamic>> _userLessons() {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUid)
      .collection('lessons');
}

Future<List<SavedLesson>> _cloudLoad() async {
  final snap =
      await _userLessons().orderBy('savedAt', descending: true).get();
  return snap.docs
      .map((d) => SavedLesson(id: d.id, lesson: LessonSet.fromJson(d.data())))
      .toList();
}

Future<SavedLesson> _cloudSave(LessonSet lesson) async {
  final data = lesson.toJson();
  data['savedAt'] = FieldValue.serverTimestamp(); // for "newest first" order
  final ref = await _userLessons().add(data);
  return SavedLesson(id: ref.id, lesson: lesson);
}

Future<void> _cloudDelete(String id) async {
  await _userLessons().doc(id).delete();
}

// ---------------------------------------------------------------------------
// Device storage (guests): a JSON array of {id, lesson} objects.
// ---------------------------------------------------------------------------

Future<List<SavedLesson>> _deviceLoad() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    final out = <SavedLesson>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      if (item.containsKey('lesson')) {
        // Current format: {id, lesson}.
        out.add(SavedLesson(
          id: (item['id'] ?? _newId()).toString(),
          lesson: LessonSet.fromJson(item['lesson'] as Map<String, dynamic>),
        ));
      } else {
        // Older format saved before accounts existed: the object IS the
        // lesson. Give it a fresh id so it still works.
        out.add(SavedLesson(id: _newId(), lesson: LessonSet.fromJson(item)));
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> _deviceWrite(List<SavedLesson> items) async {
  final prefs = await SharedPreferences.getInstance();
  final arr = items
      .map((s) => {'id': s.id, 'lesson': s.lesson.toJson()})
      .toList();
  await prefs.setString(_key, jsonEncode(arr));
}

Future<SavedLesson> _deviceSave(LessonSet lesson) async {
  final items = await _deviceLoad();
  final saved = SavedLesson(id: _newId(), lesson: lesson);
  items.insert(0, saved); // newest first
  await _deviceWrite(items);
  return saved;
}

Future<void> _deviceDelete(String id) async {
  final items = await _deviceLoad();
  items.removeWhere((s) => s.id == id);
  await _deviceWrite(items);
}

// A simple unique id for device-saved lessons (time + a counter so two saves
// in the same microsecond still differ).
int _counter = 0;
String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
