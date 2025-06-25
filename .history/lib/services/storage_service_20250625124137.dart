import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance.ref();

  Future<String?> pickAndUpload(String docId) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;
    final file = File(picked.path);
    final ref = _storage.child('stock_images/$docId.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
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
