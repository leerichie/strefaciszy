// lib/services/file_saver_io.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileSaver {
  static Future<String> saveFile(
    Uint8List bytes, {
    required String filename,
    required String mimeType,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$filename.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }
}
