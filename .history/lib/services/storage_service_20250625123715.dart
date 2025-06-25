// lib/services/storage_service.dart

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance;

  Future<String?> pickAndUploadStockImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final file = File(picked.path);
    final name = p.basename(picked.path);
    final ref = _storage.ref().child('stock_images').child(name);
    final snap = await ref.putFile(file);
    return await snap.ref.getDownloadURL();
  }

  Future<String?> pickAndUploadProjectImage(String projectId) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final file = File(picked.path);
    final name = p.basename(picked.path);
    final ref = _storage
        .ref()
        .child('project_images')
        .child(projectId)
        .child(name);
    final snap = await ref.putFile(file);
    return await snap.ref.getDownloadURL();
  }
}
