// lib/services/audit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  AuditService._();

  static Future<void> logAction({
    required String action,
    required String customerId,
    required String projectId,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      displayName = user.displayName ?? user.email ?? user.uid;
    }
    final timestamp = FieldValue.serverTimestamp();

    final payload = {
      'userId': user.uid,
      'userName': displayName,
      'action': action,
      'details': details ?? {},
      'timestamp': timestamp,
      'customerId': customerId,
      'projectId': projectId,
    };

    await FirebaseFirestore.instance.collection('audit_logs').add(payload);

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId)
        .collection('audit_logs')
        .add(payload);
  }
}
