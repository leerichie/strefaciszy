// lib/services/file_saver_io.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves bytes to a file on Android/iOS (and other non‐web platforms).
/// Returns the full path of the saved file, or null if the share sheet was shown (iOS).
class FileSaver {
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    String? mimeType,
  }) async {
    final name = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';

    // ANDROID: write to Download/MyAppExports
    if (Platform.isAndroid) {
      final base = Directory('/storage/emulated/0/Download');
      final dir = Directory('${base.path}/MyAppExports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    }

    // iOS & others: write to app documents
    final appDoc = await getApplicationDocumentsDirectory();
    final path = '${appDoc.path}/$name';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // iOS: immediately open the share sheet
    if (Platform.isIOS) {
      await Share.shareFiles([path], text: 'Your exported file');
      return null;
    }

    // other platforms: just return the path
    return path;
  }
}
