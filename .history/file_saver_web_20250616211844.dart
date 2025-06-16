// lib/services/file_saver_web.dart

import 'dart:typed_data';
import 'dart:html' as html;

class FileSaver {
  /// Triggers a browser download of [bytes] named [filename].
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
