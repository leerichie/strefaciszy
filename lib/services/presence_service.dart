// services/presence_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('presence')
        .doc('current');
  }

  String _platform() {
    if (kIsWeb) return 'web';
    return 'mobile';
  }

  Future<void> setActiveChat(String chatId) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    await _ref(u.uid).set({
      'activeChatId': chatId,
      'platform': _platform(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearActiveChat(String chatId) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(u.uid));
      final current = (snap.data() ?? {})['activeChatId'];
      if (current == chatId) {
        tx.set(_ref(u.uid), {
          'activeChatId': null,
          'platform': _platform(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}
