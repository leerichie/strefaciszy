import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
            final data = doc.data() as Map<String, dynamic>;

            final typeMatch =
                _selectedType == null || data['type'] == _selectedType;
            final userMatch =
                _userFilter.isEmpty ||
                (data['createdBy'] ?? '').toLowerCase().contains(_userFilter);

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
                items: ['RW', 'MM'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
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
                    final data = doc.data() as Map<String, dynamic>;

                    final createdAt = (data['createdAt'] as String?) ?? '';
                    final date = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.tryParse(createdAt) ?? DateTime.now());

                    final uid = data['createdBy'] ?? '';
                    _fetchUserName(uid);
                    return ListTile(
                      title: Text(
                        '${data['type'] ?? 'RW'} - ${data['projectName'] ?? ''}',
                      ),
                      subtitle: Text(
                        'Data: $date\nUżytkownik: ${userNames[uid] ?? uid}',
                      ),

                      isThreeLine: true,
                      onTap: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Szczegóły dokumentu'),
                          content: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 400),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Projekt: ${data['projectName']}'),
                                  Text('Typ: ${data['type']}'),
                                  Text('Utworzono: $date'),
                                  SizedBox(height: 10),
                                  Text('Materiały:'),
                                  ...((data['items'] as List<dynamic>?) ?? []).map(
                                    (item) => Text(
                                      '${item['name']} - ${item['quantity']} szt',
                                    ),
                                  ),
                                ],
                              ),
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
                      ),
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

  Future<void> _fetchUserName(String uid) async {
    if (userNames.containsKey(uid)) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      final name = data?['name'] ?? data?['email'] ?? uid;
      setState(() {
        userNames[uid] = name;
      });
    } catch (e) {
      setState(() {
        userNames[uid] = uid; // fallback
      });
    }
  }

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Dokument'];

    // Header
    sheet.appendRow([
      TextCellValue('Typ'),
      TextCellValue('Projekt'),
      TextCellValue('Utworzono'),
      TextCellValue('Użytkownik'),
    ]);

    sheet.appendRow([
      TextCellValue(data['type'] ?? ''),
      TextCellValue(data['projectName'] ?? ''),
      TextCellValue(data['createdAt'] ?? ''),
      TextCellValue(data['createdBy'] ?? ''),
    ]);

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Nazwa materiału'), TextCellValue('Ilość')]);

    for (var item in (data['items'] as List<dynamic>? ?? [])) {
      sheet.appendRow([
        TextCellValue(item['name'] ?? ''),
        TextCellValue(item['quantity'].toString()),
      ]);
    }

    final bytes = excel.encode();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/dokument_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes!);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Zapisano plik: ${file.path}')));
  }
}
