// lib/screens/rw_documents_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:strefa_ciszy/services/file_saver.dart';
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
                (item) => Text('${item['name']} — ${item['quantity']} szt'),
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
            onPressed: () =>
                _exportToExcel(context, data, shareAfterExport: false),
            child: Text('Exportuj do Excel'),
          ),
          TextButton(
            onPressed: () =>
                _exportToExcel(context, data, shareAfterExport: true),
            child: Text('Wyślij mailem'),
          ),
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

  Future<void> _shareViaEmail(String filePath, String fileName) async {
    final Email email = Email(
      body: 'Raport w załączniku: $fileName',
      subject: fileName,
      recipients: [],
      attachmentPaths: [filePath],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      final mailto = Uri(
        scheme: 'mailto',
        query: Uri.encodeFull(
          'subject=$fileName&body=Załącz plik ręcznie z lokalizacji: $filePath',
        ),
      );

      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nie ma apka email.')));
      }
    }
  }

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data, {
    bool shareAfterExport = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Dokument'];
    final headerStyle = CellStyle(bold: true, fontSize: 14);
    final labelStyle = CellStyle(bold: true, fontSize: 12);
    final valueStyle = CellStyle(fontSize: 12);

    // build and style header row
    sheet.appendRow([
      TextCellValue('Typ:'),
      TextCellValue('Klient:'),
      TextCellValue('Projekt:'),
      TextCellValue('Utworzono:'),
      TextCellValue('Użytkownik:'),
    ]);
    for (var c = 0; c < 5; c++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
              .cellStyle =
          headerStyle;
    }

    // parse and format timestamp
    final rawTs = data['createdAt'] as String? ?? '';
    final dt = DateTime.tryParse(rawTs) ?? DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy', 'pl_PL').format(dt);
    final timeStr = DateFormat('HH:mm', 'pl_PL').format(dt);

    // fetch display name
    final uid = data['createdBy'] as String? ?? '';
    final createdByName = userNames[uid] ?? uid;

    // values row
    sheet.appendRow([
      TextCellValue(data['type'] ?? ''),
      TextCellValue(data['customerName'] ?? ''),
      TextCellValue(data['projectName'] ?? ''),
      TextCellValue('$dateStr $timeStr'),
      TextCellValue(createdByName),
    ]);
    for (var c = 0; c < 5; c++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
              .cellStyle =
          valueStyle;
    }

    sheet.appendRow(<CellValue>[]);

    sheet.appendRow([TextCellValue('Nazwa materiału'), TextCellValue('Ilość')]);
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
            .cellStyle =
        labelStyle;
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
            .cellStyle =
        labelStyle;

    var row = 4;
    for (final item in (data['items'] as List<dynamic>? ?? [])) {
      sheet.appendRow([
        TextCellValue(item['name'] ?? ''),
        TextCellValue(item['quantity']?.toString() ?? ''),
      ]);
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .cellStyle =
          valueStyle;
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .cellStyle =
          valueStyle;
      row++;
    }

    final safeProj = (data['projectName'] as String? ?? 'dokument').replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final stamp = DateFormat(
      'dd.MM.yyyy_HH.mm',
      'pl_PL',
    ).format(DateTime.now());
    final filename = '${safeProj}_$stamp';

    // save
    final bytes = Uint8List.fromList(excel.encode()!);
    String? savedPath;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Brak uprawnień')));
          return;
        }
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      savedPath = filePath;
    } catch (e) {
      debugPrint('Error saving file: $e');
    }

    if (savedPath != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Zapisano plik: $savedPath')));
      if (shareAfterExport) {
        await _shareViaEmail(savedPath, '$filename.xlsx');
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nie udało się zapisać')));
    }
  }
}
