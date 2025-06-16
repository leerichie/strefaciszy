// lib/services/file_saver_io.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles saving bytes to a real file on Android/iOS/desktop.
class FileSaver {
  /// Writes [bytes] to `[filename].xlsx`.
  /// Returns the full path on Android/desktop, or `null` after sharing on iOS.
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    String? mimeType, // unused on IO
  }) async {
    final name = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';

    // — Android: place in Download/MyAppExports —
    if (Platform.isAndroid) {
      final base = Directory('/storage/emulated/0/Download');
      final dir = Directory('${base.path}/MyAppExports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    }

    // — iOS & other non-Android: app documents directory —
    final appDoc = await getApplicationDocumentsDirectory();
    final path = '${appDoc.path}/$name';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // On iOS, pop up the share sheet:
    if (Platform.isIOS) {
      await Share.shareFiles([path], text: 'Here’s your export');
      return null;
    }

    // On desktop or other platforms, just return path
    return path;
  }
}
