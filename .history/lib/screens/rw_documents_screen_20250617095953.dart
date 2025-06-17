// lib/screens/rw_documents_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strefa_ciszy/services/file_saver.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:permission_handler/permission_handler.dart';

class RWDocumentsScreen extends StatefulWidget {
  const RWDocumentsScreen({super.key});
  @override
  _RWDocumentsScreenState createState() => _RWDocumentsScreenState();
}

class _RWDocumentsScreenState extends State<RWDocumentsScreen> {
  String? _selectedType;
  String _userFilter = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, String> userNames = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dokumenty RW/MM')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rw_documents')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          final filtered = docs.where((doc) {
            final d = doc.data()! as Map<String, dynamic>;
            final typeMatch =
                _selectedType == null || d['type'] == _selectedType;
            final userMatch =
                _userFilter.isEmpty ||
                (d['createdBy'] ?? '').toString().toLowerCase().contains(
                  _userFilter,
                );
            final created =
                DateTime.tryParse(d['createdAt'] ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final fromOk = _fromDate == null || !created.isBefore(_fromDate!);
            final toOk = _toDate == null || !created.isAfter(_toDate!);
            return typeMatch && userMatch && fromOk && toOk;
          }).toList();
          if (filtered.isEmpty) {
            return Center(child: Text('Brak zapisanych dokumentów.'));
          }
          return Column(
            children: [
              DropdownButton<String>(
                value: _selectedType,
                hint: Text('Typ dokumentu'),
                items: ['RW', 'MM']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(labelText: 'Użytkownik'),
                  onChanged: (value) =>
                      setState(() => _userFilter = value.trim().toLowerCase()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _userFilter = '';
                        _fromDate = null;
                        _toDate = null;
                      });
                    },
                    child: Text('Resetuj filtry'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _fromDate = picked);
                    },
                    child: Text(
                      _fromDate == null
                          ? 'Data od'
                          : 'Od: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(_fromDate!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _toDate = picked);
                    },
                    child: Text(
                      _toDate == null
                          ? 'Data do'
                          : 'Do: ${DateFormat('dd.MM.yyyy', 'pl_PL').format(_toDate!)}',
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final d = doc.data()! as Map<String, dynamic>;
                    final rawDate = d['createdAt'] as String? ?? '';
                    final dt = DateTime.tryParse(rawDate) ?? DateTime.now();
                    final date = DateFormat(
                      'dd.MM.yyyy HH:mm',
                      'pl_PL',
                    ).format(dt);
                    final uid = d['createdBy'] ?? '';
                    _fetchUserName(uid);
                    return ListTile(
                      title: Text('${d['type']} — ${d['projectName'] ?? ''}'),
                      subtitle: Text(
                        'Data: $date\nUżytkownik: ${userNames[uid] ?? uid}',
                      ),
                      isThreeLine: true,
                      onTap: () => _showDetailsDialog(context, d),
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

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final rawTs = data['createdAt'] as String? ?? '';
    final dt = DateTime.tryParse(rawTs) ?? DateTime.now();
    final date = DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(dt);

    final uid = data['createdBy'] as String? ?? '';
    final name = userNames[uid] ?? '...';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Szczegóły dokumentu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Projekt: ${data['projectName']}'),
              Text('Typ: ${data['type']}'),
              Text('Utworzono: $date'),
              Text('Użytkownik: $name'),
              SizedBox(height: 16),
              Text('Materiały:'),
              ...((data['items'] as List<dynamic>?) ?? []).map(
                (item) => Text(
                  '${item['name']} — ${item['quantity']} ${item['unit'] ?? ''}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Zamknij'),
          ),
          TextButton(
            onPressed: () => _exportToExcel(context, data),
            child: Text('Exportuj do Excel'),
          ),
          // TextButton(
          //   onPressed: () =>
          //       _exportToExcel(context, data, shareAfterExport: true),
          //   child: Text('Wyślij mailem'),
          // ),
        ],
      ),
    );
  }

  Future<void> _fetchUserName(String uid) async {
    if (userNames.containsKey(uid)) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      setState(() {
        userNames[uid] = data?['name'] ?? data?['email'] ?? uid;
      });
    } catch (_) {
      setState(() {
        userNames[uid] = uid;
      });
    }
  }

  // Future<void> _shareViaEmail(String filePath, String fileName) async {
  //   final Email email = Email(
  //     body: 'Raport w załączniku: $fileName',
  //     subject: fileName,
  //     recipients: [],
  //     attachmentPaths: [filePath],
  //     isHTML: false,
  //   );

  //   try {
  //     await FlutterEmailSender.send(email);
  //   } catch (error) {
  //     final mailto = Uri(
  //       scheme: 'mailto',
  //       query: Uri.encodeFull(
  //         'subject=$fileName&body=Załącz plik ręcznie z lokalizacji: $filePath',
  //       ),
  //     );

  //     if (await canLaunchUrl(mailto)) {
  //       await launchUrl(mailto);
  //     } else {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(SnackBar(content: Text('Nie ma apka email.')));
  //     }
  //   }
  // }

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Dokument';

    // Set column widths
    sheet.getRangeByName('A1').columnWidth = 30;
    sheet.getRangeByName('B1').columnWidth = 20;
    sheet.getRangeByName('C1').columnWidth = 30;
    sheet.getRangeByName('D1').columnWidth = 20;
    // sheet.getRangeByName('E1').columnWidth = 20;

    // Add headers
    sheet.getRangeByName('A1').setText('Typ:');
    // sheet.getRangeByName('B1').setText('Klient:');
    sheet.getRangeByName('B1').setText('Projekt:');
    sheet.getRangeByName('C1').setText('Utworzono:');
    sheet.getRangeByName('D1').setText('Użytkownik:');
    sheet.getRangeByName('A1:D1').cellStyle.bold = true;

    final rawTs = data['createdAt'] as String? ?? '';
    final dt = DateTime.tryParse(rawTs) ?? DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(dt);
    final uid = data['createdBy'] ?? '';
    final createdByName = userNames[uid] ?? uid;

    sheet.getRangeByName('A2').setText(data['type'] ?? '');
    // sheet.getRangeByName('B2').setText(data['customerName'] ?? '');
    sheet.getRangeByName('B2').setText(data['projectName'] ?? '');
    sheet.getRangeByName('C2').setText(dateStr);
    sheet.getRangeByName('D2').setText(createdByName);

    // Items
    final startRow = 4;
    sheet.getRangeByName('A$startRow').setText('Materiał');
    sheet.getRangeByName('B$startRow').setText('Ilość');
    sheet.getRangeByName('C$startRow').setText('Jm');
    final headerRange = sheet.getRangeByName('A$startRow:C$startRow');
    headerRange.cellStyle.bold = true;

    sheet.getRangeByName('B$startRow').cellStyle.hAlign =
        xlsio.HAlignType.right;
    sheet.getRangeByName('C$startRow').cellStyle.hAlign =
        xlsio.HAlignType.center;

    int row = startRow + 1;
    for (final item in (data['items'] as List<dynamic>? ?? [])) {
      final name = item['name'] ?? '';
      final qty = item['quantity']?.toString() ?? '';
      final unit = item['unit']?.toString() ?? '';

      sheet.getRangeByName('A$row').setText(name);

      final qtyCell = sheet.getRangeByName('B$row');
      qtyCell.setText(qty);
      qtyCell.cellStyle.hAlign = xlsio.HAlignType.right;

      final unitCell = sheet.getRangeByName('C$row');
      unitCell.setText(unit);
      unitCell.cellStyle.hAlign = xlsio.HAlignType.center;

      row++;
    }

    final bytes = Uint8List.fromList(workbook.saveAsStream());
    workbook.dispose();

    final safeProj = (data['projectName'] as String? ?? 'dokument').replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final stamp = DateFormat(
      'dd.MM.yyyy_HH.mm',
      'pl_PL',
    ).format(DateTime.now());
    final filename = '${safeProj}_$stamp';

    final savedPath = await FileSaver.saveFile(
      bytes,
      filename: filename,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Zapisano: ${savedPath ?? "plik pobrany"}')),
    );

    if (savedPath != null && !kIsWeb) {
      await OpenFile.open(savedPath); // Only on mobile/desktop
    }
  }
}
