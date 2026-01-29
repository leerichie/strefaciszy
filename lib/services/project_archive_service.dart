// services/project_archive_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectArchiveService {
  static DocumentReference<Map<String, dynamic>> _projectRef({
    required String customerId,
    required String projectId,
  }) {
    return FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
  }

  /// Sets:
  /// archived=true, archivedAt=serverTimestamp, archivedBy=currentUid
  static Future<void> archiveProject({
    required String customerId,
    required String projectId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final ref = _projectRef(customerId: customerId, projectId: projectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Project not found');

      final data = snap.data() ?? {};
      if (data['archived'] == true) return; // already archived

      tx.update(ref, {
        'archived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': uid,
      });
    });
  }

  /// Optional (if you ever want undo for admins)
  static Future<void> unarchiveProject({
    required String customerId,
    required String projectId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final ref = _projectRef(customerId: customerId, projectId: projectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Project not found');

      final data = snap.data() ?? {};
      if (data['archived'] != true) return;

      tx.update(ref, {
        'archived': false,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
        'unarchivedAt': FieldValue.serverTimestamp(),
        'unarchivedBy': uid,
      });
    });
  }

  /// Convenience read
  static Future<bool> isProjectArchived({
    required String customerId,
    required String projectId,
  }) async {
    final snap = await _projectRef(
      customerId: customerId,
      projectId: projectId,
    ).get();
    final data = snap.data();
    return (data?['archived'] == true);
  }
}
