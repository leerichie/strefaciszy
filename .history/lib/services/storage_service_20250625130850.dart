import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Compress a file to ~80% quality and max 1080px dimensions.
  Future<File> _compressFile(File file) async {
    final targetPath = p.join(file.parent.path, 'cmp_${p.basename(file.path)}');
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );
    return result ?? file;
  }

  /// Inventory/stock image uploader (camera only), now compressed.
  Future<String?> pickAndUpload(String docId) async {
    // 1) Pick from camera
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;

    // 2) Compress
    final rawFile = File(picked.path);
    final file = await _compressFile(rawFile);

    // 3) Unique filename
    final ext = p.extension(file.path);
    final fileName = '$docId-${DateTime.now().millisecondsSinceEpoch}$ext';

    // 4) Upload
    final ref = _storage.ref().child('stock_images').child(fileName);
    await ref.putFile(file);

    // 5) Return download URL
    return await ref.getDownloadURL();
  }

  /// Project image uploader (camera or gallery), now compressed.
  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    // 1) Pick from given source
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;

    // 2) Compress
    final rawFile = File(picked.path);
    final file = await _compressFile(rawFile);

    // 3) Unique filename
    final ext = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';

    // 4) Upload into project_images/{projectId}/
    final ref = _storage
        .ref()
        .child('project_images')
        .child(projectId)
        .child(fileName);
    await ref.putFile(file);

    // 5) Return download URL
    return await ref.getDownloadURL();
  }
}
