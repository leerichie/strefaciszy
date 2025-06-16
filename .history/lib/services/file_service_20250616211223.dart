// lib/services/file_saver.dart

import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Only import dart:html on web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class FileSaver {
  /// Saves [bytes] as a file called [filename] on each platform.
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    String? mimeType,
  }) async {
    final name = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';

    // --- WEB ---
    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', name)
        ..click();
      html.Url.revokeObjectUrl(url);
      return null; // nothing to return on web
    }

    // --- ANDROID ---
    if (Platform.isAndroid) {
      // Use the Documents folder on external storage
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.documents,
      );
      final dir = dirs!.first;
      final path = '${dir.path}/$name';
      final file = File(path);
      await file.writeAsBytes(bytes);
      return path;
    }

    // --- iOS (and others) ---
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // On iOS we pop up the share sheet so the user can export it
    if (Platform.isIOS) {
      await Share.shareFiles([path], text: 'Your exported file');
      return null;
    }

    return path;
  }
}
