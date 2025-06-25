// lib/services/storage_service.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// FOR INVENTORY (stock_images): camera only, tags file with your docId
  Future<String?> pickAndUploadStockImage(String docId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;
    return _uploadFile(
      folder: 'stock_images',
      idSegment: docId,
      file: File(picked.path),
    );
  }

  /// FOR PROJECTS (project_images): camera or gallery, folder per projectId
  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;
    return _uploadFile(
      folder: 'project_images/$projectId',
      idSegment: null,
      file: File(picked.path),
    );
  }

  Future<String> uploadStockFile(String docId, File file) async {
    return _uploadFile(folder: 'stock_images', idSegment: docId, file: file);
  }

  /// INTERNAL: does the actual putFile + returns the download URL
  Future<String> _uploadFile({
    required String folder,
    String? idSegment,
    required File file,
  }) async {
    final ext = p.extension(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = idSegment != null
        ? '$idSegment-$timestamp$ext'
        : '$timestamp$ext';

    final ref = _storage.ref().child(folder).child(name);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
