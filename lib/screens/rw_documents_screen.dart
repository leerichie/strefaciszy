// lib/screens/rw_documents_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/audit_service.dart';
import 'package:strefa_ciszy/services/file_saver.dart';
import 'package:strefa_ciszy/services/stock_service.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:strefa_ciszy/widgets/audit_log_list.dart';

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
        // automaticallyImplyLeading: false,
        centerTitle: true,
        title: (widget.customerId != null && widget.projectId != null)
            ? FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
                future: Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
                  FirebaseFirestore.instance
                      .collection('customers')
                      .doc(widget.customerId)
                      .get(),
                  FirebaseFirestore.instance
                      .collection('customers')
                      .doc(widget.customerId)
                      .collection('projects')
                      .doc(widget.projectId)
                      .get(),
                ]),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done ||
                      !snap.hasData)
                    return const Text("RW");
                  final List<DocumentSnapshot<Map<String, dynamic>>> docs =
                      snap.data!;

                  final custData = docs[0].data()!;
                  final projData = docs[1].data()!;
                  final custName = custData['name'] ?? '–';
                  final projName = projData['title'] ?? '–';

                  return RichText(
                    text: TextSpan(
                      // style:
                      //     Theme.of(context).appBarTheme.titleTextStyle ??
                      //     DefaultTextStyle.of(context).style,
                      children: [
                        //   TextSpan(
                        //     text: 'RW: ',
                        //     style: TextStyle(
                        //       color: Colors.black,
                        //       fontSize: 18,
                        //       fontWeight: FontWeight.bold,
                        //     ),
                        //   ),
                        TextSpan(
                          text: '$custName: ',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: projName,
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            : RichText(
                text: TextSpan(
                  style:
                      Theme.of(context).appBarTheme.titleTextStyle ??
                      DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: 'RW – wszystkie',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              child: IconButton(
                icon: const Icon(Icons.home),
                color: Colors.white,
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainMenuScreen(role: 'admin'),
                    ),
                    (route) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // Search + Reset
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

                  // parse created
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

                    final rawTs = d['createdAt'];
                    final ts = rawTs is Timestamp
                        ? rawTs.toDate()
                        : DateTime.tryParse(rawTs.toString()) ?? DateTime.now();
                    final date = DateFormat(
                      'dd.MM.yyyy • HH:mm',
                      'pl_PL',
                    ).format(ts);

                    final uid = d['createdBy'] as String? ?? '';
                    _fetchUserName(uid);
                    final displayName = userNames[uid] ?? uid;

                    final startOfDay = DateTime(ts.year, ts.month, ts.day);
                    final startOfTomorrow = startOfDay.add(
                      const Duration(days: 1),
                    );
                    final now = DateTime.now();
                    final isToday =
                        now.isAfter(startOfDay) &&
                        now.isBefore(startOfTomorrow);

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
                          icon: Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Usuń dokument',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                title: Text('Usuń dokument?'),
                                content: Text(
                                  'Na pewno usunąć dokument ${d['type']}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx2, false),
                                    child: Text('Anuluj'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx2, true),
                                    child: Text('Usuń'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;

                            final data = d;
                            final items =
                                (data['items'] as List<dynamic>? ?? [])
                                    .cast<Map<String, dynamic>>();

                            for (var it in items) {
                              final id = it['itemId'] as String;
                              final qty = (it['quantity'] as num).toInt();
                              await StockService.increaseQty(id, qty);
                            }

                            final projectRef = FirebaseFirestore.instance
                                .collection('customers')
                                .doc(widget.customerId!)
                                .collection('projects')
                                .doc(widget.projectId!);

                            final summary = items
                                .map((it) {
                                  final name =
                                      it['name'] as String? ?? it['itemId'];
                                  final qty = it['quantity'] as num;
                                  final unit = it['unit'] as String? ?? '';
                                  return '$name (${qty.toInt()}$unit)';
                                })
                                .join(', ');

                            await AuditService.logAction(
                              action: 'Usunięto ${data['type']}',
                              customerId: widget.customerId!,
                              projectId: widget.projectId!,
                              details: {
                                'Klient': data['customerName'] ?? '',
                                'Projekt': data['projectName'] ?? '',
                                'Produkt': summary,
                                'Zmiana': summary,
                              },
                            );

                            await doc.reference.delete();

                            await projectRef.update({
                              'items': <Map<String, dynamic>>[],
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Usunięty, stan przywrócony'),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    return ListTile(
                      title: Text(
                        '${d['type']} — ${d['customerName'] ?? ''} - ${d['projectName'] ?? ''}',
                      ),
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
              child: AuditLogList(
                stream: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(widget.customerId!)
                    .collection('projects')
                    .doc(widget.projectId!)
                    .collection('audit_logs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                showContextLabels: false,
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
    final List<String> headers = [
      'Typ',
      'Klient',
      'Projekt',
      'Utworzono',
      'Użytkownik',
    ];

    final String when = data['createdAt'] is Timestamp
        ? DateFormat(
            'dd.MM.yyyy HH:mm',
          ).format((data['createdAt'] as Timestamp).toDate())
        : data['createdAt']?.toString() ?? '';
    final String rawUid = data['createdBy']?.toString() ?? '';
    final String displayName = userNames[rawUid] ?? rawUid;

    final List<String> dataRow = [
      data['type']?.toString() ?? '',
      data['customerName']?.toString() ?? '',
      data['projectName']?.toString() ?? '',
      when,
      displayName,
    ];

    final List<String> spacer = List<String>.filled(headers.length, '');

    final List<String> materialHeader =
        <String>['Materiał', 'Ilość', 'Jm'] +
        List<String>.filled(headers.length - 3, '');

    final Iterable<List<String>> items = (data['items'] as List<dynamic>? ?? [])
        .map<List<String>>((it) {
          return <String>[
            (it['name'] ?? '').toString(),
            (it['quantity'] ?? '').toString(),
            (it['unit'] ?? '').toString(),
            ...List<String>.filled(headers.length - 3, ''),
          ];
        });

    final List<String> noteHeader =
        <String>['Notatki:'] + List<String>.filled(headers.length - 1, '');

    final Iterable<List<String>> notes =
        (data['notesList'] as List<dynamic>? ?? []).map<List<String>>((raw) {
          final m = raw as Map<String, dynamic>;
          final ts = m['createdAt'];
          final date = ts is Timestamp
              ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate())
              : '';
          final user = (m['userName'] ?? '').toString();
          final text = (m['text'] ?? '').toString();
          return <String>[
            '[$date] $user: $text',
            ...List<String>.filled(headers.length - 1, ''),
          ];
        });

    final allRows = <List<String>>[
      headers,
      dataRow,
      spacer,
      materialHeader,
      ...items,
      spacer,
      noteHeader,
      ...notes,
    ];

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
        title: Text(
          '${data['type']}: ${data['customerName']} - ${data['projectName']}',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Projekt:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['projectName'] ?? '—')),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Text(
                    'Klient:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['customerName'] ?? '—')),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Text(
                    'Utworzono:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(dateStr)),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Text(
                    'Użytkownik:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(displayName)),
                ],
              ),
              const SizedBox(height: 16),

              Text('Materiały:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

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
              }),
              Text('Notatki:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              ...((data['notesList'] as List<dynamic>? ?? []).map((raw) {
                final m = raw as Map<String, dynamic>;
                final ts = m['createdAt'];
                final date = ts is Timestamp
                    ? DateFormat(
                        'dd.MM.yyyy HH:mm',
                        'pl_PL',
                      ).format(ts.toDate())
                    : '';
                final user = m['userName'] as String? ?? '';
                final text = m['text'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• [$date] $user: $text'),
                );
              })),
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
      final lookup = data?['username'] ?? data?['name'] ?? uid;
      setState(() {
        userNames[uid] = lookup;
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
    sheet.getRangeByName('B1').setText('Klient:');
    sheet.getRangeByName('C1').setText('Projekt:');
    sheet.getRangeByName('D1').setText('Utworzono:');
    sheet.getRangeByName('E1').setText('Użytkownik:');
    sheet.getRangeByName('A1:E1').cellStyle.bold = true;

    sheet.getRangeByName('A1').columnWidth = 20;
    sheet.getRangeByName('B1').columnWidth = 30;
    sheet.getRangeByName('C1').columnWidth = 30;
    sheet.getRangeByName('D1').columnWidth = 20;
    sheet.getRangeByName('E1').columnWidth = 20;

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
    sheet.getRangeByName('B2').setText(data['customerName'] ?? '');
    sheet.getRangeByName('C2').setText(data['projectName'] ?? '');
    sheet.getRangeByName('D2').setText(dateStr);
    sheet.getRangeByName('E2').setText(createdByName);

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

      // notes
      sheet.getRangeByName('A$row').setText('Notatki:');
      sheet.getRangeByName('A$row').cellStyle.bold = true;
      row++;

      for (final raw in (data['notesList'] as List<dynamic>? ?? [])) {
        final m = raw as Map<String, dynamic>;
        final text = m['text'] as String? ?? '';
        final user = m['userName'] as String? ?? '';
        final ts = m['createdAt'];
        final date = ts is Timestamp
            ? DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(ts.toDate())
            : '';
        sheet.getRangeByName('A$row').setText('[$date] $user: $text');
        row++;
      }
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
