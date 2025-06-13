import 'dart:io';
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
}
