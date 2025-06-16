// lib/services/file_saver_web.dart

import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser download of [bytes] named [filename].
/// Returns null.
class FileSaver {
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    String? mimeType,
  }) async {
    final name = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
    final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
    return null;
  }
}
