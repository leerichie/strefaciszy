import 'dart:typed_data';
import 'dart:html' as html;

class FileSaver {
  static Future<String?> saveFile(
    Uint8List bytes, {
    required String filename,
    required String mimeType,
  }) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
    return null;
  }
}
