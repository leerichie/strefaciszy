// lib/services/storage_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';
import 'dart:io' as io;

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

    final url = await uploadStockFile(docId, xfile, overwrite: overwrite);

    if (url != null) {
      await FirebaseFirestore.instance
          .collection('stock_items')
          .doc(docId)
          .update({'imageUrl': url});
    }

    return url;
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
    required XFile file,
  }) async {
    final ext = p.extension(file.name);

    final name = idSegment != null
        ? '$idSegment$ext'
        : '${DateTime.now().millisecondsSinceEpoch}$ext';

    final ref = _storage.ref().child(folder).child(name);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      final io.File ioFile = io.File(file.path);
      await ref.putFile(ioFile);
    }

    return ref.getDownloadURL();
  }

  Future<String> uploadProjectImage(String projectId, XFile file) {
    return _uploadFile(
      folder: 'project_images/$projectId',
      idSegment: null,
      file: file,
    );
  }
}
