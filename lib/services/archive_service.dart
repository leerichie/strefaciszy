// services/archive_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ArchiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> archiveProject({
    required String projectId,
    required String projectName,
    required String archivedBy,
  }) async {
    final projectRef = _firestore.collection('projects').doc(projectId);
    final archiveRef = _firestore.collection('archives').doc();

    await _firestore.runTransaction((transaction) async {
      final projectSnap = await transaction.get(projectRef);

      if (!projectSnap.exists) {
        throw Exception("Project does not exist");
      }

      final projectData = projectSnap.data()!;

      final List<dynamic> workers = projectData['workers'] ?? [];
      final List<String> allowedUsers = workers
          .map((w) => w['userId'] as String)
          .toList();

      final archiveData = {
        "projectId": projectId,
        "projectName": projectName,
        "archivedAt": FieldValue.serverTimestamp(),
        "archivedBy": archivedBy,
        "allowedUsers": allowedUsers,
        "projectSnapshot": projectData,
      };

      transaction.set(archiveRef, archiveData);

      transaction.update(projectRef, {"isArchived": true});
    });
  }
}
