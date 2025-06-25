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

  Future<XFile?> pickImage({required ImageSource source}) async {
    return await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
  }

  Future<String?> pickAndUploadStockImage(
    String docId,
    ImageSource source, {
    bool overwrite = false,
  }) async {
    final xfile = await pickImage(source: source);
    if (xfile == null) return null;
    return uploadStockFile(docId, xfile, overwrite: overwrite);
  }

  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    final xfile = await pickImage(source: source);
    if (xfile == null) return null;
    return uploadProjectFile(projectId, xfile);
  }

  Future<String> uploadProjectFile(String projectId, dynamic file) {
    return _uploadFile(
      folder: 'project_images/$projectId',
      idSegment: null,
      file: file,
    );
  }

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

  Future<String> _uploadFile({
    required String folder,
    String? idSegment,
    required dynamic file,
  }) async {
    final ext = kIsWeb
        ? p.extension((file as XFile).name)
        : p.extension((file as File).path);

    final name = idSegment != null
        ? '$idSegment$ext'
        : '${DateTime.now().millisecondsSinceEpoch}$ext';
    final ref = _storage.ref().child(folder).child(name);

    if (kIsWeb) {
      final bytes = await (file as XFile).readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(file as File);
    }

    return ref.getDownloadURL();
  }
}
