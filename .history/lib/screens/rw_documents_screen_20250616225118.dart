import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/services/file_saver.dart';

class RWDocumentsScreen extends StatefulWidget {
  const RWDocumentsScreen({super.key});

  @override
  State<RWDocumentsScreen> createState() => _RWDocumentsScreenState();
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
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final filtered = docs.where((doc) {
            final data = doc.data()! as Map<String, dynamic>;

            final typeMatch =
                _selectedType == null || data['type'] == _selectedType;
            final userMatch =
                _userFilter.isEmpty ||
                (data['createdBy'] ?? '').toString().toLowerCase().contains(
                  _userFilter,
                );

            final created =
                DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime(2000);
            final fromOk = _fromDate == null || !created.isBefore(_fromDate!);
            final toOk = _toDate == null || !created.isAfter(_toDate!);

            return typeMatch && userMatch && fromOk && toOk;
          }).toList();

          if (filtered.isEmpty) {
            return Center(child: Text('Brak zapisanych dokumentów.'));
          }

          return Column(
            children: [
              // Filters
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
                          : 'Od: ${DateFormat('yyyy-MM-dd').format(_fromDate!)}',
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
                          : 'Do: ${DateFormat('yyyy-MM-dd').format(_toDate!)}',
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final createdAt = data['createdAt'] ?? '';
                    final date = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.tryParse(createdAt) ?? DateTime.now());

                    final uid = data['createdBy'] ?? '';
                    _fetchUserName(uid);

                    return ListTile(
                      title: Text(
                        '${data['type']} - ${data['projectName'] ?? ''}',
                      ),
                      subtitle: Text(
                        'Data: $date\nUżytkownik: ${userNames[uid] ?? uid}',
                      ),
                      isThreeLine: true,
                      onTap: () => _showDetailsDialog(context, data),
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
    final createdAt = data['createdAt'] ?? '';
    final date = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.tryParse(createdAt) ?? DateTime.now());

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
              SizedBox(height: 10),
              Text('Materiały:'),
              ...((data['items'] as List<dynamic>?) ?? []).map(
                (item) => Text('${item['name']} - ${item['quantity']} szt'),
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
            onPressed: () async {
              await _exportToExcel(context, data);
            },
            child: Text('Eksportuj do Excel'),
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
      final d = snap.data();
      final name = d?['name'] ?? d?['email'] ?? uid;
      setState(() => userNames[uid] = name);
    } catch (_) {
      setState(() => userNames[uid] = uid);
    }
  }

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
  final excel = Excel.createExcel();
  final sheet = excel['Dokument'];

  // Styles
  final headerStyle = CellStyle(
    bold: true,
    fontSize: 14,
    horizontalAlign: TextAlign.Centre,
  );
  final labelStyle = CellStyle(
    bold: true,
    fontSize: 12,
  );
  final valueStyle = CellStyle(
    fontSize: 12,
  );

  final createdAtRaw = data['createdAt'] as String? ?? '';
  final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
  final dateStr = DateFormat('dd.MM.yyyy', 'pl_PL').format(createdAt);
  final timeStr = DateFormat('HH:mm', 'pl_PL').format(createdAt);

  final customerName = data['customerName'] as String? ?? '—';

  sheet.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
  );
  sheet.appendRow([TextCellValue('DOKUMENT ${data['type']}')]);
  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    DataType.String,
    'DOKUMENT ${data['type']}',
    headerStyle,
  );

  // Blank row
  sheet.appendRow([]);

  // Info row: labels in bold, values normal
  sheet.appendRow([
    TextCellValue('Klient:'),       TextCellValue(customerName),
    TextCellValue('Projekt:'),      TextCellValue(data['projectName'] ?? '—'),
    TextCellValue('Utworzono:'),    TextCellValue('$dateStr $timeStr'),
  ]);
  final infoRow = 2;
  // Apply styles
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: infoRow))
    .cellStyle = labelStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: infoRow))
    .cellStyle = valueStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: infoRow))
    .cellStyle = labelStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: infoRow))
    .cellStyle = valueStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: infoRow))
    .cellStyle = labelStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: infoRow))
    .cellStyle = valueStyle;

  // Blank row
  sheet.appendRow([]);

  // Header for material table
  sheet.appendRow([TextCellValue('Nazwa materiału'), TextCellValue('Ilość')]);
  final headerRow = 4;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow))
    .cellStyle = headerStyle;
  sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: headerRow))
    .cellStyle = headerStyle;

  // Materials
  int row = headerRow + 1;
  for (final item in (data['items'] as List<dynamic>? ?? [])) {
    sheet.appendRow([
      TextCellValue(item['name'] ?? ''),
      TextCellValue(item['quantity'].toString()),
    ]);
    // apply normal style
    sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      .cellStyle = valueStyle;
    sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      .cellStyle = valueStyle;
    row++;
  }

  // Auto-fit or set reasonable column widths
  sheet.setColWidth(0, 30); // material name
  sheet.setColWidth(1, 10); // quantity
  sheet.setColWidth(2, 15);
  sheet.setColWidth(3, 15);
  sheet.setColWidth(4, 20);
  sheet.setColWidth(5, 10);

  // Save
  final raw = excel.encode()!;
  final bytes = Uint8List.fromList(raw);

  // build a filename: ProjectName_dd.MM.yyyy_HH.mm
  final safeProject = (data['projectName'] as String? ?? 'Dokument')
      .replaceAll(RegExp(r'\s+'), '_');
  final now = DateTime.now();
  final stamp = DateFormat('dd.MM.yyyy_HH.mm', 'pl_PL').format(now);
  final filename = '$safeProject\_$stamp';

  final savedPath = await FileSaver.saveFile(
    bytes,
    filename: filename,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        savedPath != null
            ? 'Zapisano plik: $savedPath'
            : 'Pobrano plik: $filename.xlsx',
      ),
    ),
  );
}