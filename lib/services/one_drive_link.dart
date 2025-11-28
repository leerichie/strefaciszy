// lib/services/one_drive_link.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OneDriveLink {
  static DocumentReference<Map<String, dynamic>> _projectRef(
    String customerId,
    String projectId,
  ) {
    return FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
  }

  static Future<String?> getOneDriveUrl(
    String customerId,
    String projectId,
  ) async {
    final doc = await _projectRef(customerId, projectId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    final value = data['oneDriveUrl'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static Future<void> setOneDriveUrl(
    String customerId,
    String projectId,
    String? url,
  ) async {
    final ref = _projectRef(customerId, projectId);
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await ref.update({'oneDriveUrl': FieldValue.delete()});
    } else {
      await ref.update({'oneDriveUrl': trimmed});
    }
  }
}
