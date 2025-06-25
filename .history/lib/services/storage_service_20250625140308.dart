import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> pickAndUpload(String docId) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    final file = File(picked.path);
    final ext = p.extension(picked.path);
    final fileName = '$docId-${DateTime.now().millisecondsSinceEpoch}$ext';

    final ref = _storage.ref().child('stock_images').child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70, // ← ADDED: compress to ~70%
      maxWidth: 1024, // ← ADDED: cap width
      maxHeight: 1024, // ← ADDED: cap height
    );
    if (picked == null) return null;

    final file = File(picked.path);
    final ext = p.extension(picked.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';

    final ref = _storage
        .ref()
        .child('project_images')
        .child(projectId)
        .child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
