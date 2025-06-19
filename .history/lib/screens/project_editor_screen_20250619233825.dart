// lib/screens/project_editor_screen.dart

import 'dart:async';
import 'dart:io';
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

class ProjectEditorScreen extends StatefulWidget {
  final bool isAdmin;
  final String customerId;
  final String projectId;

  const ProjectEditorScreen({
    Key? key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
  }) : super(key: key);

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

  late final StreamSubscription<QuerySnapshot<StockItem>> _stockSub;
  List<StockItem> _stockItems = [];
  List<ProjectLine> _lines = [];

  @override
  void initState() {
    super.initState();
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

    final filteredLines = _lines.where((l) => l.requestedQty > 0).toList();

    setState(() => _saving = true);

    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwCol = projectRef.collection('rw_documents');

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
    final bool existsToday = todaySnap.docs.isNotEmpty;
    final String rwId = existsToday ? todaySnap.docs.first.id : rwCol.doc().id;

    final rwRef = rwCol.doc(rwId);
    final docSnap = await rwRef.get();
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final rawTs = data['createdAt'];
      final createdAtRaw = rawTs is Timestamp ? rawTs.toDate() : now;
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

    DateTime createdAt = now;
    String createdBy = user.uid;
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final rawTs = data['createdAt'];
      createdAt = rawTs is Timestamp ? rawTs.toDate() : createdAt;
      createdBy = data['createdBy'] ?? user.uid;
    }

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
    try {
      await StockService.applyProjectLinesTransaction(
        customerId: widget.customerId,
        projectId: widget.projectId,
        rwDocId: rwId,
        rwDocData: rwData,
        isNew: !docSnap.exists,
        lines: filteredLines,
        newStatus: type,
        userId: user.uid,
      );

      setState(() {
        _lines = filteredLines;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zapisano $type – magazyn aktualny')),
      );
      await _checkTodayExists(type);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
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
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.list_alt_rounded),
            tooltip: 'Dokumenty RW/MM',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RWDocumentsScreen(
                    customerId: widget.customerId,
                    projectId: widget.projectId,
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
              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(labelText: 'Projekt'),
                onChanged: (v) => _title = v,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),

              // preview & save RW
              if (_lines.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _lines.length,
                    itemBuilder: (ctx, i) {
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

                      return ListTile(
                        title: Text(name),
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
                              icon: Icon(Icons.edit),
                              onPressed: () async {
                                final updated = await showProjectLineDialog(
                                  context,
                                  _stockItems,
                                  existing: ln,
                                );
                                if (updated != null) {
                                  setState(() => _lines[i] = updated);
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () async {
                                final removed = _lines[i];

                                if (removed.isStock) {
                                  final stockRef = FirebaseFirestore.instance
                                      .collection('stock_items')
                                      .doc(removed.itemRef);
                                  await stockRef.update({
                                    'quantity': FieldValue.increment(
                                      removed.requestedQty,
                                    ),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                    'updatedBy':
                                        FirebaseAuth.instance.currentUser!.uid,
                                  });
                                }

                                setState(() => _lines.removeAt(i));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
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

                    // Prevent duplicates
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
                          content: Text(
                            'Nie mozna dodac bo pozycja juz istnieje!',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() => _lines.add(lineWithUnit));
                  },
                  child: Icon(Icons.add),
                ),
              ),

              Divider(height: 32),

              // Images & notes preview
              // Save buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _saveRWDocument('RW'),
                    child: Text(_rwExistsToday ? 'Update RW' : 'Zapisz RW'),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveRWDocument('MM'),
                    child: Text(_mmExistsToday ? 'Update MM' : 'Zapisz MM'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
