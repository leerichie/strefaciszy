import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Your stock uploader, unchanged except unique filename:
  Future<String?> pickAndUpload(String docId) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;

    final file = File(picked.path);
    final ext = p.extension(picked.path); // .jpg/.png
    final fileName = '$docId-${DateTime.now().millisecondsSinceEpoch}$ext';

    final ref = _storage.ref().child('stock_images').child(fileName);

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Project image uploader with unique filename:
  Future<String?> pickAndUploadProjectImage(String projectId) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final file = File(picked.path);
    final ext = p.extension(picked.path);
    // you could also use Uuid().v4() here instead of timestamp
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
