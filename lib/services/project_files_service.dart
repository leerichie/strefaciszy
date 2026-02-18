// lib/services/project_files_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ProjectFilesService {
  static String? _guessContentType(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.txt':
        return 'text/plain';
      case '.rtf':
        return 'application/rtf';
      case '.csv':
        return 'text/csv';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return null;
    }
  }

  static Future<List<Map<String, String>>> uploadProjectFilesFromBytes({
    required String customerId,
    required String projectId,
    required List<MapEntry<String, Uint8List>> files,
    required String tabBucket,
  }) async {
    if (files.isEmpty) return const [];

    final rawStorageBucket = Firebase.app().options.storageBucket ?? '';
    final storageBucketUri = rawStorageBucket.startsWith('gs://')
        ? rawStorageBucket
        : 'gs://$rawStorageBucket';

    final storage = FirebaseStorage.instanceFor(bucket: storageBucketUri);

    final uploadFutures = files.map((entry) async {
      final name = entry.key;
      final data = entry.value;

      final ref = storage.ref().child('project_files/$projectId/$name');

      final contentType = _guessContentType(name);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      try {
        if (metadata != null) {
          await ref.putData(data, metadata);
        } else {
          await ref.putData(data);
        }

        final url = await ref.getDownloadURL();
        return {'url': url, 'name': name, 'bucket': tabBucket};
      } catch (e, st) {
        debugPrint(
          'UPLOAD FAILED name="$name" storageBucket="$storageBucketUri" tabBucket="$tabBucket" path="${ref.fullPath}"',
        );

        debugPrint('error=$e');
        debugPrint('$st');
        rethrow;
      }
    }).toList();

    final results = await Future.wait(uploadFutures);
    final newFiles = results.whereType<Map<String, String>>().toList(
      growable: false,
    );

    if (newFiles.isEmpty) return const [];

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    await docRef.update({'files': FieldValue.arrayUnion(newFiles)});

    return newFiles;
  }

  // SHARE - uploads
  static Future<List<Map<String, String>>> uploadProjectImagesFromBytes({
    required String customerId,
    required String projectId,
    required List<MapEntry<String, Uint8List>> files,
    required String tabBucket, // pass 'images'
  }) async {
    if (files.isEmpty) return const [];

    final rawStorageBucket = Firebase.app().options.storageBucket ?? '';
    final storageBucketUri = rawStorageBucket.startsWith('gs://')
        ? rawStorageBucket
        : 'gs://$rawStorageBucket';

    final storage = FirebaseStorage.instanceFor(bucket: storageBucketUri);

    final uploadFutures = files.map((entry) async {
      final name = entry.key;
      final data = entry.value;

      final ref = storage.ref().child('project_images/$projectId/$name');

      final contentType = _guessContentType(name);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;

      if (metadata != null) {
        await ref.putData(data, metadata);
      } else {
        await ref.putData(data);
      }

      final url = await ref.getDownloadURL();
      return {'url': url, 'name': name, 'bucket': tabBucket};
    }).toList();

    final results = await Future.wait(uploadFutures);
    final newFiles = results.whereType<Map<String, String>>().toList(
      growable: false,
    );

    if (newFiles.isEmpty) return const [];

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    await docRef.update({'files': FieldValue.arrayUnion(newFiles)});

    return newFiles;
  }

  static Future<void> deleteProjectFile({
    required String customerId,
    required String projectId,
    required String url,
    required String name,
    required String bucket,
  }) async {
    final storage = FirebaseStorage.instanceFor(
      bucket: 'gs://${Firebase.app().options.storageBucket}',
    );

    try {
      await storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Couldn’t delete from storage: $e');
    }

    final docRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    await docRef.update({
      'files': FieldValue.arrayRemove([
        {'url': url, 'name': name, 'bucket': bucket},
      ]),
    });
  }
}
