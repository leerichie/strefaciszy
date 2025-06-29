// lib/screens/rw_documents_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/file_saver.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:strefa_ciszy/widgets/project_history_list.dart';

class RWDocumentsScreen extends StatefulWidget {
  final String? customerId;
  final String? projectId;
  final bool isAdmin;
  const RWDocumentsScreen({
    super.key,
    this.customerId,
    this.projectId,
    required this.isAdmin,
  });

  @override
  _RWDocumentsScreenState createState() => _RWDocumentsScreenState();
}

class _RWDocumentsScreenState extends State<RWDocumentsScreen> {
  String? _selectedType;
  String _userFilter = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, String> userNames = {};

  late final TextEditingController _searchController;

  Stream<QuerySnapshot> get _stream {
    final db = FirebaseFirestore.instance;

    if (widget.customerId != null && widget.projectId != null) {
      return db
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .collection('rw_documents')
          .orderBy('createdDay', descending: true)
          .snapshots();
    }

    if (widget.customerId != null) {
      return db
          .collectionGroup('rw_documents')
          .where('customerId', isEqualTo: widget.customerId)
          .orderBy('createdDay', descending: true)
          .snapshots();
    }

    return db
        .collectionGroup('rw_documents')
        .orderBy('createdDay', descending: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClientView = widget.customerId != null;

    return Scaffold(
      appBar: AppBar(
        title: isClientView && widget.projectId != null
            ? FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(widget.customerId)
                    .collection('projects')
                    .doc(widget.projectId)
                    .get(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Text('RW');
                  }
                  if (!snap.hasData || !snap.data!.exists) {
                    return const Text('RW');
                  }
                  final data = snap.data!.data()! as Map<String, dynamic>;
                  final projectName = data['title'] as String? ?? '–';
                  return Text('RW • $projectName');
                },
              )
            : const Text('RW/MM - wszystkie'),
      ),

      body: Column(
        children: [
          // ─── Search + Reset ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Wyszukaj...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _userFilter = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Resetuj'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedType = null;
                      _userFilter = '';
                      _fromDate = null;
                      _toDate = null;
                      _searchController.clear();
                    });
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─── RW DOCUMENTS LIST (TOP HALF) ───────────────────────────────────
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;
                final filtered = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;

                  // parse createdAt
                  DateTime created;
                  final rawCreated = d['createdAt'];
                  if (rawCreated is Timestamp) {
                    created = rawCreated.toDate();
                  } else if (rawCreated is String) {
                    created = DateTime.tryParse(rawCreated) ?? DateTime(2000);
                  } else {
                    created = DateTime(2000);
                  }

                  final uid = d['createdBy'] ?? '';
                  final uName =
                      userNames[uid]?.toLowerCase() ?? uid.toLowerCase();
                  final proj = (d['projectName'] ?? '')
                      .toString()
                      .toLowerCase();

                  final textOk =
                      _userFilter.isEmpty ||
                      uName.contains(_userFilter.toLowerCase()) ||
                      proj.contains(_userFilter.toLowerCase());
                  final typeOk =
                      _selectedType == null || d['type'] == _selectedType;
                  final fromOk =
                      _fromDate == null || !created.isBefore(_fromDate!);
                  final toOk = _toDate == null || !created.isAfter(_toDate!);

                  return textOk && typeOk && fromOk && toOk;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Brak zapisanych dokumentów.'),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final d = doc.data()! as Map<String, dynamic>;

                    // format created date
                    final rawTs = d['createdAt'];
                    final ts = rawTs is Timestamp
                        ? rawTs.toDate()
                        : DateTime.tryParse(rawTs.toString()) ?? DateTime.now();
                    final date = DateFormat(
                      'dd.MM.yyyy • HH:mm',
                      'pl_PL',
                    ).format(ts);

                    // fetch and display the username
                    final uid = d['createdBy'] as String? ?? '';
                    _fetchUserName(uid);
                    final displayName = userNames[uid] ?? uid;

                    // determine if it's today
                    final startOfDay = DateTime(ts.year, ts.month, ts.day);
                    final startOfTomorrow = startOfDay.add(
                      const Duration(days: 1),
                    );
                    final now = DateTime.now();
                    final isToday =
                        now.isAfter(startOfDay) &&
                        now.isBefore(startOfTomorrow);

                    // action buttons
                    final actions = <Widget>[];
                    if (isToday) {
                      actions.add(
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edytuj dokument',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectEditorScreen(
                                  customerId: widget.customerId!,
                                  projectId: widget.projectId!,
                                  isAdmin: widget.isAdmin,
                                  rwId: doc.id,
                                  rwCreatedAt: ts,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    if (widget.isAdmin) {
                      actions.add(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Usuń dokument',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                title: const Text('Usuń dokument?'),
                                content: Text(
                                  'Na pewno usunąć dokument ${d['type']}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx2, false),
                                    child: const Text('Anuluj'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx2, true),
                                    child: const Text('Usuń'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dokument usunięty'),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    }

                    return ListTile(
                      title: Text('${d['type']} — ${d['projectName'] ?? ''}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(date),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(displayName),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => _showDetailsDialog(context, d),
                      trailing: actions.isEmpty
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                    );
                  },
                );
              },
            ),
          ),

          // ─── HISTORY (BOTTOM HALF) ──────────────────────────────────────────────
          if (isClientView) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Historia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              flex: 1,
              child: ProjectHistoryList(
                customerId: widget.customerId!,
                projectId: widget.projectId!,
              ),
            ),
          ],
        ],
      ),

      floatingActionButton: !kIsWeb
          ? FloatingActionButton(
              tooltip: 'Skanuj',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: const Icon(Icons.qr_code_scanner, size: 32),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Inwentaryzacja',
                  icon: const Icon(Icons.inventory_2),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: true),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.group),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildCsv(Map<String, dynamic> data, Map<String, String> userNames) {
    final headers = ['Typ', 'Projekt', 'Utworzono', 'Użytkownik'];
    final createdAt = data['createdAt'];
    final when = createdAt is Timestamp
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())
        : createdAt.toString();
    final rawUid = data['createdBy']?.toString() ?? '';
    final displayName = userNames[rawUid] ?? rawUid;
    final dataRow = [
      data['type'] ?? '',
      data['projectName'] ?? '',
      when,
      displayName,
    ];

    final spacer = ['', '', '', ''];
    final materialHeader = ['Material', 'Ilość', 'Jm', ''];
    final items = (data['items'] as List<dynamic>? ?? []).map<List<String>>((
      it,
    ) {
      return [
        it['name'] ?? '',
        it['quantity']?.toString() ?? '',
        it['unit'] ?? '',
        '',
      ];
    });

    final allRows = [headers, dataRow, spacer, materialHeader, ...items];

    return allRows.map((row) => row.join('\t')).join('\r\n');
  }

  Future<void> _copyCsv(Map<String, dynamic> data) async {
    final csv = _buildCsv(data, userNames);
    await Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Skopiowany do schowka')));
  }

  Future<void> _showDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    DateTime dt;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else if (raw is String) {
      dt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(dt);

    final uid = data['createdBy'] as String? ?? '';
    String displayName;

    if (userNames.containsKey(uid)) {
      displayName = userNames[uid]!;
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final u = snap.data();
        displayName = u?['name'] ?? u?['email'] ?? uid;
      } catch (_) {
        displayName = uid;
      }
      setState(() => userNames[uid] = displayName);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Szczegóły – ${data['type']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Projekt: ${data['projectName']}'),
              Text('Utworzono: $dateStr'),
              Text('Użytkownik: $displayName'),
              const SizedBox(height: 16),
              Text('Materiały:'),
              ...((data['items'] as List<dynamic>?) ?? []).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Expanded(flex: 4, child: Text(item['name'] ?? '')),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${item['quantity'] ?? ''}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['unit'] ?? '',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyCsv(data),
            child: const Text('Kopiuj'),
          ),
          TextButton(
            onPressed: () => _exportToExcel(context, data),
            child: const Text('Exportuj do Excel'),
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

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Dokument';

    sheet.getRangeByName('A1').columnWidth = 30;
    sheet.getRangeByName('B1').columnWidth = 20;
    sheet.getRangeByName('C1').columnWidth = 30;
    sheet.getRangeByName('D1').columnWidth = 20;

    sheet.getRangeByName('A1').setText('Typ:');
    sheet.getRangeByName('B1').setText('Projekt:');
    sheet.getRangeByName('C1').setText('Utworzono:');
    sheet.getRangeByName('D1').setText('Użytkownik:');
    sheet.getRangeByName('A1:D1').cellStyle.bold = true;

    final rawTs = data['createdAt'];
    DateTime dt;
    if (rawTs is Timestamp) {
      dt = rawTs.toDate();
    } else if (rawTs is String) {
      dt = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(dt);

    final uid = data['createdBy'] ?? '';
    final createdByName = userNames[uid] ?? uid;

    sheet.getRangeByName('A2').setText(data['type'] ?? '');
    sheet.getRangeByName('B2').setText(data['projectName'] ?? '');
    sheet.getRangeByName('C2').setText(dateStr);
    sheet.getRangeByName('D2').setText(createdByName);

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

    if (!kIsWeb) {
      await OpenFile.open(savedPath);
    }
  }
}
