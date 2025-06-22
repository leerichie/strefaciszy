// lib/services/audit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  AuditService._();

  /// Writes a new entry into the top‐level "audit_logs" collection.
  static Future<void> logAction({
    required String action,
    String? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = user.displayName ?? user.email ?? user.uid;
    final col = FirebaseFirestore.instance.collection('audit_logs');
    await col.add({
      'userId': user.uid,
      'userName': name,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
