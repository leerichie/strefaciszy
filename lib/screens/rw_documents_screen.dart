// lib/screens/rw_documents_screen.dart

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/swap_workflow_screen.dart';
import 'package:strefa_ciszy/services/audit_service.dart';
import 'package:strefa_ciszy/services/file_saver.dart';
import 'package:strefa_ciszy/services/stock_service.dart';
import 'package:strefa_ciszy/utils/colour_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
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
  bool _hasEditableDocs = false;
  bool _hasItemsInProject = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _projectSub;
  String prettyType(String raw) => raw == 'RW' ? 'Raport' : raw;

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

  Future<void> _evaluateHasItemsIncludingHistory() async {
    if (widget.customerId == null || widget.projectId == null) return;

    bool hasAny = false;

    // 1. Check live project items
    try {
      final projSnap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId!)
          .collection('projects')
          .doc(widget.projectId!)
          .get();
      final projData = projSnap.data() ?? <String, dynamic>{};
      final projectItems = (projData['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      hasAny = projectItems.any((it) {
        final parsedQty = _parseQty(it['quantity']);
        return parsedQty > 0;
      });
      debugPrint('Live project items hasAny: $hasAny');
    } catch (e) {
      debugPrint('Error reading project items for swap/return check: $e');
    }

    // 2. Fallback to any item present in any RW document if live is empty
    if (!hasAny) {
      try {
        final docsSnap = await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId!)
            .collection('projects')
            .doc(widget.projectId!)
            .collection('rw_documents')
            .get();

        for (final doc in docsSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final docItems = (data['items'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final docHas = docItems.any((it) {
            final parsedQty = _parseQty(it['quantity']);
            return parsedQty > 0;
          });
          if (docHas) {
            hasAny = true;
            break;
          }
        }
        debugPrint('Historic RW documents fallback hasAny: $hasAny');
      } catch (e) {
        debugPrint('Error reading RW documents for swap/return fallback: $e');
      }
    }

    if (mounted && _hasItemsInProject != hasAny) {
      setState(() {
        _hasItemsInProject = hasAny;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    if (widget.customerId != null && widget.projectId != null) {
      final projectRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          );

      _projectSub = FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId!)
          .collection('projects')
          .doc(widget.projectId!)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
            toFirestore: (m, _) => m,
          )
          .snapshots()
          .listen((snap) {
            // Whenever project doc changes, reevaluate whether ANY items exist (live or in history).
            _evaluateHasItemsIncludingHistory();
          });
    }
  }

  // detect any old project item
  int _parseQty(dynamic qty) {
    if (qty is num) return qty.toInt();
    if (qty is String) {
      final cleaned = qty.replaceAll(',', '.').trim();
      final doubleVal = double.tryParse(cleaned);
      if (doubleVal != null) return doubleVal.round();
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  @override
  void dispose() {
    _projectSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClientView = widget.customerId != null;

    final titleWidg = (widget.customerId != null && widget.projectId != null)
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
              if (snap.connectionState != ConnectionState.done) {
                return const Text("Raport");
              }
              if (snap.hasError) {
                return const Text("Raport");
              }
              final docs = snap.data;
              if (docs == null || docs.length < 2) {
                return const Text("Raport");
              }

              final custSnap = docs[0];
              final projSnap = docs[1];

              final custData = custSnap.data() ?? <String, dynamic>{};
              final projData = projSnap.data() ?? <String, dynamic>{};

              final custName = (custData['name'] as String?)?.toString() ?? '–';
              final projName =
                  (projData['title'] as String?)?.toString() ?? '–';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AutoSizeText(
                    custName,
                    style: const TextStyle(color: Colors.black),
                    maxLines: 1,
                    minFontSize: 8,
                  ),
                  AutoSizeText(
                    projName,
                    style: TextStyle(color: Colors.red.shade900),
                    maxLines: 1,
                    minFontSize: 8,
                  ),
                ],
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
                  text: 'Raport – wszystkie',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );

    return AppScaffold(
      floatingActionButton:
          widget.customerId != null &&
              widget.projectId != null &&
              _hasItemsInProject
          ? FloatingActionButton(
              tooltip: 'Swap',
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => SwapWorkflowScreen(
                      customerId: widget.customerId!,
                      projectId: widget.projectId!,
                      isAdmin: widget.isAdmin,
                    ),
                  ),
                );
                if (changed == true && mounted) {
                  setState(() {});
                }
              },
              child: const Icon(Icons.swap_horiz, size: 32),
            )
          : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      title: '',
      titleWidget: titleWidg,
      centreTitle: true,

      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

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

                final hasEditable = filtered.any((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final rawCreated = d['createdAt'];
                  DateTime created;
                  if (rawCreated is Timestamp) {
                    created = rawCreated.toDate();
                  } else if (rawCreated is String) {
                    created = DateTime.tryParse(rawCreated) ?? DateTime(2000);
                  } else {
                    created = DateTime(2000);
                  }

                  final startOfDay = DateTime(
                    created.year,
                    created.month,
                    created.day,
                  );
                  final startOfTomorrow = startOfDay.add(
                    const Duration(days: 1),
                  );
                  final now = DateTime.now();

                  return now.isAfter(startOfDay) &&
                      now.isBefore(startOfTomorrow);
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _hasEditableDocs != hasEditable) {
                    setState(() {
                      _hasEditableDocs = hasEditable;
                    });
                  }
                });

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
                    if (!userNames.containsKey(uid)) {
                      _fetchUserName(uid);
                    }
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
                    final rawType = (d['type']?.toString() ?? '');

                    return ListTile(
                      title: Text(
                        '${prettyType(rawType)}: ${d['customerName'] ?? ''} • ${d['projectName'] ?? ''}',
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
                              Flexible(
                                flex: 2,
                                child: Text(
                                  date,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 1,
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: colourFromString(displayName),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // isThreeLine: true,
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
    );
  }

  Future<String> _resolveUserDisplayName(String uid) async {
    if (userNames.containsKey(uid)) return userNames[uid]!;
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
      return name;
    } catch (_) {
      setState(() {
        userNames[uid] = uid;
      });
      return uid;
    }
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

    final rawNotes = data['notesList'] as List<dynamic>? ?? [];

    final resolvedNotes = <Map<String, dynamic>>[];
    for (final raw in rawNotes) {
      final m = raw as Map<String, dynamic>;
      final uidForNote = (m['userName'] ?? '').toString();
      final displayName = await _resolveUserDisplayName(uidForNote);

      resolvedNotes.add({
        'createdAt': m['createdAt'],
        'displayName': displayName,
        'text': m['text'] ?? '',
        'action': m['action'] ?? '',
      });
    }

    // Sort by createdAt ascending
    resolvedNotes.sort((a, b) {
      final da = (a['createdAt'] as Timestamp).toDate();
      final db = (b['createdAt'] as Timestamp).toDate();
      return da.compareTo(db);
    });
    final rawType = (data['type']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${prettyType(rawType)}: ${data['customerName']} - ${data['projectName']}',
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

              ...((data['items'] as List<dynamic>?) ?? []).map((item) {
                final prod = (item['producent'] ?? '').toString();
                final name = (item['name'] ?? '').toString();
                final qty = (item['quantity'] ?? '').toString();
                final unit = (item['unit'] ?? '').toString();
                final fullName = prod.isNotEmpty ? '$prod $name' : name;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$fullName     $qty $unit.',
                          style: TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              Text('Notatki:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final m in resolvedNotes) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Builder(
                    builder: (_) {
                      // safe parsing of createdAt
                      final rawCreated = m['createdAt'];
                      DateTime noteDt;
                      if (rawCreated is Timestamp) {
                        noteDt = rawCreated.toDate();
                      } else if (rawCreated is String) {
                        noteDt =
                            DateTime.tryParse(rawCreated) ?? DateTime.now();
                      } else {
                        noteDt = DateTime.now();
                      }
                      final noteDateStr = DateFormat(
                        'dd.MM.yyyy HH:mm',
                        'pl_PL',
                      ).format(noteDt);
                      final action = (m['action'] as String).isNotEmpty
                          ? '${m['action']}: '
                          : '';
                      final displayName = m['displayName'] ?? '';
                      final text = m['text'] ?? '';

                      return Text(
                        '• [$noteDateStr] $action$displayName: $text',
                      );
                    },
                  ),
                ),
              ],
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

    final rawType = data['type']?.toString() ?? '';

    final List<String> dataRow = [
      prettyType(rawType),
      data['customerName']?.toString() ?? '',
      data['projectName']?.toString() ?? '',
      when,
      displayName,
    ];

    final List<String> spacer = List<String>.filled(headers.length, '');

    final List<String> materialHeader =
        <String>['Opis', 'Producent', 'Model', 'Ilość', 'Jm'] +
        List<String>.filled(headers.length - 5, '');

    final Iterable<List<String>> items = (data['items'] as List<dynamic>? ?? [])
        .map<List<String>>((it) {
          return <String>[
            (it['description'] ?? '').toString(),
            (it['producent'] ?? '').toString(),
            (it['name'] ?? '').toString(),
            (it['quantity'] ?? '').toString(),
            (it['unit'] ?? '').toString(),
            ...List<String>.filled(headers.length - 5, ''),
          ];
        });

    final List<String> noteHeader =
        <String>['Notatki:'] + List<String>.filled(headers.length - 1, '');

    final List<Map<String, dynamic>> rawNotes =
        ((data['notesList'] as List<dynamic>?) ?? [])
            .map((raw) => raw as Map<String, dynamic>)
            .toList();

    final resolvedNotes = <Map<String, dynamic>>[];
    for (final m in rawNotes) {
      final ts = m['createdAt'];
      final date = ts is Timestamp
          ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate())
          : '';
      final user = (m['userName'] ?? '').toString();
      final action = (m['action'] ?? '').toString();
      final text = (m['text'] ?? '').toString();
      final prefix = action.isNotEmpty ? '$action: ' : '';
      resolvedNotes.add({
        'formatted': '[$date] $prefix$user: $text',
        'createdAt': ts,
      });
    }
    resolvedNotes.sort((a, b) {
      final da = (a['createdAt'] as Timestamp).toDate();
      final db = (b['createdAt'] as Timestamp).toDate();
      return da.compareTo(db);
    });

    final Iterable<List<String>> notes = resolvedNotes.map<List<String>>((r) {
      return <String>[
        r['formatted'] as String,
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
    // dump raw
    final items = (data['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    for (var it in items) {
      debugPrint('CSV debug: item raw: $it');
      debugPrint(
        'CSV debug: quantity field: ${it['quantity']} (type: ${it['quantity']?.runtimeType})',
      );
    }

    final csv = _buildCsv(data, userNames);
    debugPrint('COPY CSV RAW:\n$csv');

    await Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Skopiowany do schowka')));
  }

  Future<void> _exportToExcel(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Dokument';

    sheet.getRangeByName('A1').columnWidth = 20;
    sheet.getRangeByName('B1').columnWidth = 30;
    sheet.getRangeByName('C1').columnWidth = 35;
    sheet.getRangeByName('D1').columnWidth = 20;
    sheet.getRangeByName('E1').columnWidth = 20;

    sheet.getRangeByName('A1').setText('Typ:');
    sheet.getRangeByName('B1').setText('Klient:');
    sheet.getRangeByName('C1').setText('Projekt:');
    sheet.getRangeByName('D1').setText('Utworzono:');
    sheet.getRangeByName('E1').setText('Użytkownik:');

    final titleHeader = sheet.getRangeByName('A1:E1');
    titleHeader.cellStyle.bold = true;
    titleHeader.cellStyle.fontColor = '#FFFFFF';
    titleHeader.cellStyle.backColor = '#000000';

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
    final displayName = userNames[uid] ?? uid;

    final rawType = data['type']?.toString() ?? '';
    sheet.getRangeByName('A2').setText(prettyType(rawType));
    sheet.getRangeByName('B2').setText(data['customerName']?.toString() ?? '');
    sheet.getRangeByName('C2').setText(data['projectName']?.toString() ?? '');
    sheet.getRangeByName('D2').setText(dateStr);
    sheet.getRangeByName('E2').setText(displayName);

    const startRow = 4;
    sheet.getRangeByName('A$startRow').setText('Opis');
    sheet.getRangeByName('B$startRow').setText('Producent');
    sheet.getRangeByName('C$startRow').setText('Model');
    sheet.getRangeByName('D$startRow').setText('Ilość');
    sheet.getRangeByName('E$startRow').setText('Jm');

    final headerRange = sheet.getRangeByName('A$startRow:E$startRow');
    headerRange.cellStyle.bold = true;
    headerRange.cellStyle.fontColor = '#FFFFFF';
    headerRange.cellStyle.backColor = '#000000';
    sheet.getRangeByName('D$startRow').cellStyle.hAlign =
        xlsio.HAlignType.right;
    sheet.getRangeByName('E$startRow').cellStyle.hAlign =
        xlsio.HAlignType.center;

    int row = startRow + 1;
    for (final item in (data['items'] as List<dynamic>? ?? [])) {
      final desc = item['description']?.toString() ?? '';
      final prod = item['producent']?.toString() ?? '';
      final name = item['name']?.toString() ?? '';
      final qty = item['quantity']?.toString() ?? '';
      final unit = item['unit']?.toString() ?? '';

      sheet.getRangeByName('A$row').setText(desc);
      sheet.getRangeByName('B$row').setText(prod);
      sheet.getRangeByName('C$row').setText(name);

      final qtyCell = sheet.getRangeByName('D$row');
      qtyCell.setText(qty);
      qtyCell.cellStyle.hAlign = xlsio.HAlignType.right;

      final unitCell = sheet.getRangeByName('E$row');
      unitCell.setText(unit);
      unitCell.cellStyle.hAlign = xlsio.HAlignType.center;

      row++;
    }

    sheet.getRangeByName('A$row').setText('Notatki:');
    sheet.getRangeByName('A$row').cellStyle.bold = true;
    row++;

    final rawNotes = (data['notesList'] as List<dynamic>?) ?? [];
    final notesList = rawNotes
        .map((raw) => raw as Map<String, dynamic>)
        .toList();
    notesList.sort((a, b) {
      final da = (a['createdAt'] as Timestamp).toDate();
      final db = (b['createdAt'] as Timestamp).toDate();
      return da.compareTo(db);
    });

    // resolve and sort notes to mirror UI
    final resolvedNotes = <Map<String, dynamic>>[];
    for (final m in notesList) {
      final ts = m['createdAt'];
      final dateStr = ts is Timestamp
          ? DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(ts.toDate())
          : '';
      final user = (m['userName'] ?? '').toString();
      final action = (m['action'] ?? '').toString();
      final text = (m['text'] ?? '').toString();
      final prefix = action.isNotEmpty ? '$action:' : '';
      resolvedNotes.add({
        'sortKey': ts,
        'line': '[$dateStr] $prefix$user: $text',
      });
    }
    resolvedNotes.sort((a, b) {
      final da = (a['sortKey'] as Timestamp).toDate();
      final db = (b['sortKey'] as Timestamp).toDate();
      return da.compareTo(db);
    });

    for (final note in resolvedNotes) {
      final line = note['line'] as String;
      sheet.getRangeByName('A$row').setText(line);
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
      SnackBar(content: Text('Zapisano: ${savedPath ?? 'plik pobrany'}')),
    );
    if (!kIsWeb) {
      await OpenFile.open(savedPath);
    }
  }
}
