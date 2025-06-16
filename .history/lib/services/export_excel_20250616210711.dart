// lib/services/export_service.dart
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExportService {
  /// Exports a document map to an .xlsx file and returns its path.
  static Future<String> exportToExcel(Map<String, dynamic> data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Dokument'];
    sheet.appendRow(['Typ', 'Projekt', 'Utworzono', 'Użytkownik']);
    sheet.appendRow([
      data['type'] ?? '',
      data['projectName'] ?? '',
      data['createdAt'] ?? '',
      data['createdBy'] ?? '',
    ]);
    sheet.appendRow([]);
    sheet.appendRow(['Nazwa materiału', 'Ilość']);
    for (var item in (data['items'] as List? ?? [])) {
      sheet.appendRow([item['name'] ?? '', item['quantity'].toString()]);
    }

    final bytes = excel.encode();
    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/dokument_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(filePath).writeAsBytes(bytes!);
    return filePath;
  }
}
