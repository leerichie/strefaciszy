import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FilteredReportScreen extends StatelessWidget {
  final String reportType;
  final DateTimeRange? customRange;
  final String? userFilter;
  final String? itemFilter;
  final String usageType;

  const FilteredReportScreen({
    super.key,
    required this.reportType,
    required this.customRange,
    required this.userFilter,
    required this.itemFilter,
    required this.usageType,
  });

  DateTimeRange getDateRangeFromType() {
    final now = DateTime.now();
    switch (reportType) {
      case 'Tygodniowy':
        return DateTimeRange(start: now.subtract(Duration(days: 7)), end: now);
      case 'Miesięczny':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'Roczny':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case 'Zakres własny':
        return customRange ?? DateTimeRange(start: now, end: now);
      default:
        return DateTimeRange(start: now.subtract(Duration(days: 30)), end: now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = getDateRangeFromType();

    return Scaffold(
      appBar: AppBar(title: Text('Wyniki raportu')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rw_documents')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final created =
                DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime(2000);
            final user = (data['createdBy'] ?? '').toString().toLowerCase();
            final items = (data['items'] as List<dynamic>?) ?? [];

            final matchUser =
                userFilter == null || user.contains(userFilter!.toLowerCase());
            final matchDate =
                !created.isBefore(range.start) && !created.isAfter(range.end);

            final matchItem =
                itemFilter == null ||
                items.any((item) {
                  return (item['name'] ?? '').toString().toLowerCase().contains(
                    itemFilter!.toLowerCase(),
                  );
                });

            final matchUsage =
                usageType == 'Wszystkie' ||
                items.any(
                  (item) =>
                      (usageType == 'Zużyte' && item['used'] == true) ||
                      (usageType == 'Zwrócone' && item['returned'] == true),
                );

            return matchUser && matchDate && matchItem && matchUsage;
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(child: Text('Brak wyników dla wybranych filtrów.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => _exportToExcel(context, filteredDocs),
                  icon: Icon(Icons.download),
                  label: Text('Eksportuj do Excel'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] ?? '';
                    final date = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.tryParse(createdAt) ?? DateTime.now());

                    return ListTile(
                      title: Text(
                        '${data['type']} - ${data['projectName'] ?? ''}',
                      ),
                      subtitle: Text(
                        'Użytkownik: ${data['createdBy'] ?? ''}\nData: $date',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportToExcel(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Raport'];

    sheet.appendRow([
      TextCellValue('Data'),
      TextCellValue('Użytkownik'),
      TextCellValue('Typ'),
      TextCellValue('Projekt'),
      TextCellValue('Materiał'),
      TextCellValue('Ilość'),
      TextCellValue('Typ zużycia'),
    ]);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final created = data['createdAt'] ?? '';
      final user = data['createdBy'] ?? '';
      final type = data['type'] ?? '';
      final project = data['projectName'] ?? '';

      final items = (data['items'] as List?) ?? [];

      for (final item in items) {
        final name = item['name'] ?? '';
        final qty = item['quantity'] ?? '';
        final usageLabel = item['returned'] == true
            ? 'Zwrócone'
            : item['used'] == true
            ? 'Zużyte'
            : '';

        if (itemFilter != null &&
            itemFilter!.isNotEmpty &&
            !name.toLowerCase().contains(itemFilter!.toLowerCase())) {
          continue;
        }

        sheet.appendRow([
          TextCellValue(created),
          TextCellValue(user),
          TextCellValue(type),
          TextCellValue(project),
          TextCellValue(name),
          TextCellValue(qty.toString()),
          TextCellValue(usageLabel),
        ]);
      }
    }

    final bytes = excel.encode();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/raport_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes!);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Zapisano plik: ${file.path}')));

    // 📤 Share via email or apps
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Raport materiałowy Strefa Ciszy',
      subject: 'Raport RW/MM z aplikacji',
    );
  }
}
