import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
  static int _saveRevision = 0;

  static Future<void> loadForSignedInUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final revision = _saveRevision;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (revision == _saveRevision &&
          FirebaseAuth.instance.currentUser?.uid == uid) {
        isDarkMode.value = snapshot.data()?['darkMode'] == true;
      }
    } catch (_) {
      // Keep the light theme if the saved preference cannot be reached.
    }
  }

  static Future<void> saveForSignedInUser(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    _saveRevision++;
    isDarkMode.value = value;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'darkMode': value},
      SetOptions(merge: true),
    );
  }
}
