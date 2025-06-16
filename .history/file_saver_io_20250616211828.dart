// lib/services/file_saver_io.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileSaver {
  /// Writes [bytes] to a file called [filename].
  /// Returns the saved path on Android or non-iOS platforms,
  /// returns `null` on Web or after showing iOS share sheet.
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    String? mimeType,
  }) async {
    final name = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';

    // Android: write to external Documents
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.documents,
      );
      final dir = dirs!.first;
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    }

    // iOS & others: write to app documents
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
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
