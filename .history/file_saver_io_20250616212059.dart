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

    if (Platform.isAndroid) {
      final base = Directory('/storage/emulated/0/Download');
      final dir = Directory('${base.path}/MyAppExports');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}/$name';
      // write your file…
    }

    // iOS & others: write to app documents
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // iOS & others
    final dir = await getApplicationDocumentsDirectory();
    // or: final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';

    // other platforms: just return the path
    return path;
  }
}
