// lib/services/storage_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';
import 'dart:io' show File;

class StorageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Let the user pick an image (camera or gallery) with compression.
  /// Returns an XFile (web/mobile) or null if cancelled.
  Future<XFile?> pickImage({required ImageSource source}) async {
    return await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
  }

  /// Pick + upload in one step for stock images (overwrites if specified).
  Future<String?> pickAndUploadStockImage(
    String docId,
    ImageSource source, {
    bool overwrite = false,
  }) async {
    final xfile = await pickImage(source: source);
    if (xfile == null) return null;
    return uploadStockFile(docId, xfile, overwrite: overwrite);
  }

  /// Pick + upload in one step for project images.
  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    final xfile = await pickImage(source: source);
    if (xfile == null) return null;
    return uploadProjectFile(projectId, xfile);
  }

  /// Upload a project image (always timestamped).
  Future<String> uploadProjectFile(String projectId, dynamic file) {
    return _uploadFile(
      folder: 'project_images/$projectId',
      idSegment: null,
      file: file,
    );
  }

  /// Upload a stock image.
  /// If [overwrite] is true, uses just the docId so it replaces the previous file.
  Future<String> uploadStockFile(
    String docId,
    dynamic file, {
    bool overwrite = false,
  }) {
    final idSegment = overwrite
        ? docId
        : '$docId-${DateTime.now().millisecondsSinceEpoch}';
    return _uploadFile(
      folder: 'stock_images',
      idSegment: idSegment,
      file: file,
    );
  }

  /// Internal helper: picks the right upload method for web vs mobile
  Future<String> _uploadFile({
    required String folder,
    String? idSegment,
    required dynamic file, // XFile on web, File on mobile
  }) async {
    // Determine extension from name (web) or path (mobile)
    final ext = kIsWeb
        ? p.extension((file as XFile).name)
        : p.extension((file as File).path);

    // Build filename
    final name = idSegment != null
        ? '$idSegment$ext'
        : '${DateTime.now().millisecondsSinceEpoch}$ext';
    final ref = _storage.ref().child(folder).child(name);

    if (kIsWeb) {
      // On web: read bytes and upload with putData
      final bytes = await (file as XFile).readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      // On mobile: upload the File directly
      await ref.putFile(file as File);
    }

    // Return the download URL
    return ref.getDownloadURL();
  }
}
