// lib/services/audit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  AuditService._();

  static Future<void> logAction({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1) Try to read your Firestore users collection
    String displayName;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      displayName = (data != null && data['name'] != null)
          ? data['name'] as String
          : (user.displayName ?? user.email ?? user.uid);
    } catch (e) {
      // On any error, still fall back
      displayName = user.displayName ?? user.email ?? user.uid;
    }

    // 2) Write the audit log
    final col = FirebaseFirestore.instance.collection('audit_logs');
    await col.add({
      'userId': user.uid,
      'userName': displayName,
      'action': action,
      'details': details ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
