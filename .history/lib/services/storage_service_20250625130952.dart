import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<File> _compressFile(File file) async {
    final targetPath = p.join(file.parent.path, 'cmp_${p.basename(file.path)}');

    final File? result =
        (await FlutterImageCompress.compressAndGetFile(
              file.path,
              targetPath,
              quality: 80,
              minWidth: 1080,
              minHeight: 1080,
            ))
            as File?;

    return result ?? file;
  }

  Future<String?> pickAndUpload(String docId) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;

    final rawFile = File(picked.path);
    final file = await _compressFile(rawFile);

    final ext = p.extension(file.path);
    final fileName = '$docId-${DateTime.now().millisecondsSinceEpoch}$ext';

    final ref = _storage.ref().child('stock_images').child(fileName);
    await ref.putFile(file);

    return await ref.getDownloadURL();
  }

  Future<String?> pickAndUploadProjectImage(
    String projectId,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;

    final rawFile = File(picked.path);
    final file = await _compressFile(rawFile);

    final ext = p.extension(file.path);
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
