// lib/screens/project_editor_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/services/stock_service.dart';
import 'package:strefa_ciszy/widgets/project_line_dialog.dart';
import 'package:strefa_ciszy/models/rw_document.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/audit_service.dart';

class ProjectEditorScreen extends StatefulWidget {
  final bool isAdmin;
  final String customerId;
  final String projectId;
  final String? rwId;
  final DateTime? rwCreatedAt;

  const ProjectEditorScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
    this.rwId,
    this.rwCreatedAt,
  });

  @override
  _ProjectEditorScreenState createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _rwExistsToday = false;
  bool _mmExistsToday = false;

  String _title = '';
  String _status = 'draft';
  String _notes = '';
  List<XFile> _images = [];
  String _customerName = '';

  late final StreamSubscription<QuerySnapshot<StockItem>> _stockSub;
  List<StockItem> _stockItems = [];
  List<ProjectLine> _lines = [];
  late final bool _rwLocked;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .get()
        .then((snap) {
          if (snap.exists) {
            setState(() {
              _customerName = snap.data()!['name'] as String? ?? '';
            });
          }
        });
    final today = DateTime.now();
    final created = widget.rwCreatedAt;
    _rwLocked =
        !widget.isAdmin &&
        created != null &&
        (created.year != today.year ||
            created.month != today.month ||
            created.day != today.day);
    _stockSub = FirebaseFirestore.instance
        .collection('stock_items')
        .withConverter<StockItem>(
          fromFirestore: (snap, _) => StockItem.fromMap(snap.data()!, snap.id),
          toFirestore: (item, _) => item.toMap(),
        )
        .snapshots()
        .listen((snap) {
          setState(() => _stockItems = snap.docs.map((d) => d.data()).toList());
        });
    _loadAll();
    _checkTodayExists('RW');
    _checkTodayExists('MM');
    _scheduleMidnightRollover();
  }

  @override
  void dispose() {
    _stockSub.cancel();
    super.dispose();
  }

  void _scheduleMidnightRollover() {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1));
    final untilMidnight = tomorrow.difference(now);

    Timer(untilMidnight, () async {
      if (!mounted) return;

      await _loadAll();

      await _checkTodayExists('RW');
      await _checkTodayExists('MM');

      _scheduleMidnightRollover();
    });
  }

  Future<void> _loadAll() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final snap = await projRef.get();
    final data = snap.data()!;

    final lastRwRaw = data['lastRwDate'];
    DateTime? lastRwDate = lastRwRaw is Timestamp ? lastRwRaw.toDate() : null;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    if (lastRwDate == null || lastRwDate.isBefore(startOfDay)) {
      await projRef.update({
        'items': <Map<String, dynamic>>[],
        'status': 'draft',
      });
      _lines = [];
    } else {
      _lines = (data['items'] as List<dynamic>? ?? [])
          .map((m) => ProjectLine.fromMap(m))
          .toList();
    }

    _title = data['title'] as String? ?? '';
    _status = data['status'] as String? ?? 'draft';
    _notes = data['notes'] as String? ?? '';
    _images = (data['images'] as List<dynamic>? ?? [])
        .cast<String>()
        .map((u) => XFile(u))
        .toList();

    setState(() {
      _loading = false;
      _initialized = true;
    });
  }

  Future<void> _checkTodayExists(String type) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfDay.add(Duration(days: 1));

    final dayStamp = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day).toUtc(),
    );

    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .collection('rw_documents')
        .where('type', isEqualTo: type)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    setState(() {
      if (type == 'RW') {
        _rwExistsToday = snap.docs.isNotEmpty;
      } else /* 'MM' */ {
        _mmExistsToday = snap.docs.isNotEmpty;
      }
    });
  }

  Future<void> _saveRWDocument(String type) async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 0) Fetch human-readable client & project names
    final custSnap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .get();
    final customerName =
        custSnap.data()?['name'] as String? ?? '<nieznany klient>';

    final projSnap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .get();
    final projectName =
        projSnap.data()?['title'] as String? ?? '<nieznany projekt>';

    // 1) Prepare the lines
    final fullLines = List<ProjectLine>.from(_lines);
    final filteredLines = fullLines.where((l) => l.requestedQty > 0).toList();

    setState(() => _saving = true);

    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwCol = projectRef.collection('rw_documents');

    // 2) Find or create today's RW
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfDay.add(Duration(days: 1));
    final todaySnap = await rwCol
        .where('type', isEqualTo: type)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    final existsToday = todaySnap.docs.isNotEmpty;
    final rwId = existsToday ? todaySnap.docs.first.id : rwCol.doc().id;
    final rwRef = rwCol.doc(rwId);

    // 3) Prevent editing yesterday's doc for non-admins
    final docSnap = await rwRef.get();
    if (docSnap.exists) {
      final createdAtRaw = (docSnap.data()!['createdAt'] as Timestamp).toDate();
      if (createdAtRaw.isBefore(startOfDay) && !widget.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tylko administrator może edytować dokumenty z poprzednich dni.',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }
    }

    // 4) Determine createdAt/createdBy
    DateTime createdAt = now;
    String createdBy = user.uid;
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final rawTs = data['createdAt'];
      createdAt = rawTs is Timestamp ? rawTs.toDate() : createdAt;
      createdBy = data['createdBy'] ?? createdBy;
    }

    // 5) Build the RW data map
    final rwData = StockService.buildRwDocMap(
      rwId,
      widget.projectId,
      _title,
      createdBy,
      createdAt,
      type,
      filteredLines,
      _stockItems,
      widget.customerId,
    );

    // reset qty and debug
    for (var ln in filteredLines) {
      ln.previousQty ??= 0;

      debugPrint(
        '   • ${ln.itemRef}: requestedQty=${ln.requestedQty}, previousQty=${ln.previousQty}',
      );
    }

    if (filteredLines.isEmpty && docSnap.exists) {
      // 1) Restore stock for each previously-saved line
      for (final ln in fullLines.where((l) => l.previousQty > 0)) {
        try {
          await StockService.increaseQty(ln.itemRef, ln.previousQty);
          debugPrint('🔄 Restored ${ln.previousQty} for ${ln.itemRef}');
          ln.previousQty = 0;
        } catch (e) {
          debugPrint('⚠️ Couldn\'t restore ${ln.itemRef}: $e');
        }
      }

      // 2) Audit: log that the empty RW was removed
      // 2) Lookup human-readable names up front:
      final custSnap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .get();
      final customerName = custSnap.data()?['name'] as String? ?? '–';

      final projSnap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final projectName = projSnap.data()?['title'] as String? ?? '–';

      // 3) Build a little “item1(qty), item2(qty)” summary:
      final itemSummaries = filteredLines
          .map((ln) {
            final stock = _stockItems.firstWhere((s) => s.id == ln.itemRef);
            return '${stock.name}(${ln.requestedQty})';
          })
          .join(', ');

      // 3) Actually delete the RW doc
      await rwRef.delete();
      debugPrint('🗑️ RW document $rwId deleted (no lines left)');

      // 4) Clear UI state
      setState(() {
        _lines.clear();
        _rwExistsToday = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usunięto pusty dokument $type i przywrócono stan magazynowy',
          ),
        ),
      );

      setState(() => _saving = false);
      return;
    }

    try {
      // 6) Call the transaction
      await StockService.applyProjectLinesTransaction(
        customerId: widget.customerId,
        projectId: widget.projectId,
        rwDocId: rwId,
        rwDocData: rwData,
        isNew: !existsToday,
        lines: fullLines,
        newStatus: type,
        userId: user.uid,
      );

      // build a “name(qty)” summary for the audit
      final itemSummaries = filteredLines
          .map((ln) {
            if (ln.isStock) {
              final stock = _stockItems.firstWhere((s) => s.id == ln.itemRef);
              return '${stock.name}(${ln.requestedQty})';
            } else {
              return '${ln.customName}(${ln.requestedQty})';
            }
          })
          .join(', ');

      // log create/update
      await AuditService.logAction(
        action: existsToday
            ? 'Zaktualizowano dokument RW'
            : 'Utworzono dokument RW',
        details: {
          'Klient': customerName,
          'Projekt': projectName,
          'RW ID': rwId,
          'Pozycji': filteredLines.length.toString(),
          'Szczegóły': itemSummaries,
        },
      );

      setState(() {
        for (var ln in _lines) {
          final matching = filteredLines.firstWhere(
            (f) => f.itemRef == ln.itemRef,
            orElse: () => ln,
          );
          if (ln.itemRef == matching.itemRef) {
            ln.previousQty = matching.requestedQty;
          }
        }
      });

      // 8) Re-check today’s RW state
      try {
        await _checkTodayExists(type);
      } catch (e, st) {
        debugPrint('⚠️ _checkTodayExists error: $e\n$st');
      }
    } catch (e, st) {
      // — Debug logging on failure —
      debugPrint('🔥 _saveRWDocument failed: $e');
      debugPrint('📋 Stack trace:\n$st');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: ${e.toString()}')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _openGallery() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  Future<void> _openNotes() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var draft = _notes;
        return AlertDialog(
          title: Text('Edytuj Notatki'),
          content: TextFormField(
            initialValue: draft,
            maxLines: 5,
            onChanged: (v) => draft = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, draft),
              child: Text('Zapisz'),
            ),
          ],
        );
      },
    );
    if (result != null) setState(() => _notes = result);
  }

  Future<void> _cleanupEmptyRWIfNeeded() async {
    if (_lines.isEmpty) {
      final projectRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId);
      final rwCol = projectRef.collection('rw_documents');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfDay.add(Duration(days: 1));

      final snap = await rwCol
          .where('type', isEqualTo: 'RW')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: startOfTomorrow)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.delete();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Usunięto pusty dokument RW')));
        setState(() => _rwExistsToday = false);
      }
    }
  }

  Future<void> _deleteLineFromRW(ProjectLine line) async {
    final rwCol = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .collection('rw_documents');

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfTomorrow = startOfDay.add(Duration(days: 1));

    final rwSnap = await rwCol
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .limit(1)
        .get();

    if (rwSnap.docs.isNotEmpty) {
      final rwDoc = rwSnap.docs.first;
      final rwId = rwDoc.id;
      final rwData = rwDoc.data();

      final List<dynamic> materials = List.from(rwData['lines'] ?? []);
      final updated = materials.where((m) {
        if (line.isStock) return m['itemRef'] != line.itemRef;
        return m['customName'] != line.customName;
      }).toList();

      await rwCol.doc(rwId).update({'lines': updated});
    }

    // Restore stock
    if (line.isStock) {
      final stockRef = FirebaseFirestore.instance
          .collection('stock_items')
          .doc(line.itemRef);
      await stockRef.update({
        'quantity': FieldValue.increment(line.requestedQty),
      });
    }

    // ❗️Remove from project items in Firestore
    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final projSnap = await projectRef.get();
    if (projSnap.exists) {
      final items = List<Map<String, dynamic>>.from(
        projSnap.data()?['items'] ?? [],
      );
      final newItems = items.where((m) {
        if (line.isStock) return m['itemRef'] != line.itemRef;
        return m['customName'] != line.customName;
      }).toList();
      await projectRef.update({'items': newItems});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Ładowanie...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edytuj projekt'),
        actions: [
          IconButton(
            icon: Icon(Icons.list_alt_rounded),
            tooltip: 'Dokumenty RW/MM',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RWDocumentsScreen(
                    customerId: widget.customerId,
                    projectId: widget.projectId,
                    isAdmin: widget.isAdmin,
                  ),
                ),
              );
            },
          ),
          if (widget.isAdmin)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: 'Usuń projekt',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text('Usuń projekt?'),
                    content: Text('Potwierdź usunięcie projektu.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text('Usuń'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('customers')
                      .doc(widget.customerId)
                      .collection('projects')
                      .doc(widget.projectId)
                      .delete();
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),

      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_rwLocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Dokument RW jest zablokowany do edycji.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(labelText: 'Projekt'),
                onChanged: (v) => _title = v,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),

              if (_lines.any(
                (l) => l.requestedQty > 0 && l.requestedQty != l.previousQty,
              ))
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Preview. Kliknij "Zapisz RW", aby dodać do RW.',
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_lines.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _lines.length,

                    itemBuilder: (ctx, i) {
                      final today = DateTime.now();
                      final ln = _lines[i];
                      final name = ln.isStock
                          ? _stockItems
                                .firstWhere((s) => s.id == ln.itemRef)
                                .name
                          : ln.customName;
                      final stockQty = ln.isStock
                          ? _stockItems
                                .firstWhere((s) => s.id == ln.itemRef)
                                .quantity
                          : ln.originalStock;
                      final delta = ln.requestedQty - ln.previousQty;
                      final previewQty = stockQty - delta;
                      final qtyColor = previewQty <= 0
                          ? Colors.red
                          : Colors.green;

                      final isToday =
                          ln.updatedAt == null ||
                          (ln.updatedAt!.year == today.year &&
                              ln.updatedAt!.month == today.month &&
                              ln.updatedAt!.day == today.day);

                      final isSynced =
                          ln.requestedQty == ln.previousQty &&
                          ln.requestedQty > 0;
                      final isLineLocked =
                          _rwLocked ||
                          (isSynced && !isToday && !widget.isAdmin);

                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(name)),
                            if (isSynced)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Zapisany do RW',
                                  style: TextStyle(color: Colors.green[900]),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              TextSpan(text: '${ln.requestedQty} ${ln.unit} '),
                              TextSpan(
                                text: '(stan: $previewQty)',
                                style: TextStyle(color: qtyColor),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: isLineLocked ? Colors.grey : Colors.blue,
                              ),
                              onPressed: isLineLocked
                                  ? () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Tylko administrator może edytować starsze pozycje',
                                          ),
                                        ),
                                      );
                                    }
                                  : () async {
                                      final updated =
                                          await showProjectLineDialog(
                                            context,
                                            _stockItems,
                                            existing: ln,
                                          );
                                      if (updated != null) {
                                        setState(() => _lines[i] = updated);
                                      }
                                    },
                            ),
                            if (!isLineLocked)
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final removedLine = _lines[i];
                                  setState(() => _lines.removeAt(i));
                                  await _deleteLineFromRW(ln);
                                  await _saveRWDocument('RW');

                                  removedLine.previousQty = 0;
                                  await _cleanupEmptyRWIfNeeded();
                                },
                              )
                            else
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.grey),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tylko administrator może usuwać starsze pozycje',
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _rwLocked ? null : () => _saveRWDocument('RW'),
                    child: Text(_rwExistsToday ? 'Update RW' : 'Zapisz RW'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _rwLocked
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final newLine = await showProjectLineDialog(
                  context,
                  _stockItems,
                );

                if (newLine == null) return;

                final lineWithUnit = newLine.isStock
                    ? newLine.copyWith(
                        unit: _stockItems
                            .firstWhere((s) => s.id == newLine.itemRef)
                            .unit,
                      )
                    : newLine;

                final isDup = newLine.isStock
                    ? _lines.any(
                        (l) => l.isStock && l.itemRef == newLine.itemRef,
                      )
                    : _lines.any(
                        (l) =>
                            !l.isStock &&
                            l.customName.toLowerCase() ==
                                newLine.customName.toLowerCase(),
                      );

                if (isDup) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Nie mozna dodac bo pozycja juz istnieje!'),
                    ),
                  );
                  return;
                }

                setState(() => _lines.add(lineWithUnit));
              },
              tooltip: 'Dodaj',
              child: Icon(Icons.playlist_add, size: 28),
            ),
    );
  }
}
