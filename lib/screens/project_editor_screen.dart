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
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/services/stock_service.dart';
import 'package:strefa_ciszy/widgets/project_line_dialog.dart';
import 'package:strefa_ciszy/models/rw_document.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/audit_service.dart';
import 'package:strefa_ciszy/widgets/audit_log_list.dart';
import 'package:strefa_ciszy/widgets/photo_gallery.dart';
import 'package:strefa_ciszy/widgets/notes_section.dart';

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
  List<String> _photoUrls = [];
  List<Note> _notesList = [];

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
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    projRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      setState(() {
        _photoUrls = List<String>.from(data['images'] ?? []);
        _notesList =
            (data['notesList'] as List<dynamic>? ?? []).map((m) {
                final mp = m as Map<String, dynamic>;
                return Note(
                  text: mp['text'] as String,
                  userName: mp['userName'] as String,
                  createdAt: (mp['createdAt'] as Timestamp).toDate(),
                );
              }).toList()
              // newest first
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
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

    if (widget.rwId != null) {
      final rwSnap = await projRef
          .collection('rw_documents')
          .doc(widget.rwId)
          .get();
      if (rwSnap.exists) {
        final data = rwSnap.data()!;
        final rawItems = (data['items'] as List<dynamic>?) ?? [];

        _lines = rawItems.map((e) {
          final m = e as Map<String, dynamic>;
          final itemId = m['itemId'] as String;
          final qty = (m['quantity'] as num).toInt();
          final unit = m['unit'] as String;
          final name = m['name'] as String;
          final isStock = _stockItems.any((s) => s.id == itemId);

          final originalStock = isStock
              ? _stockItems.firstWhere((s) => s.id == itemId).quantity
              : qty;

          return ProjectLine(
            isStock: isStock,
            itemRef: itemId,
            customName: isStock ? '' : name,
            requestedQty: qty,
            originalStock: originalStock,
            previousQty: qty,
            unit: unit,
          );
        }).toList();

        _title = data['projectName'] as String? ?? '';

        setState(() {
          _loading = false;
          _initialized = true;
        });
        return;
      }
    }

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

    final fullLines = List<ProjectLine>.from(_lines);
    final filteredLines = fullLines.where((l) => l.requestedQty > 0).toList();

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
    final existsToday = todaySnap.docs.isNotEmpty;
    final rwId = existsToday ? todaySnap.docs.first.id : rwCol.doc().id;
    final rwRef = rwCol.doc(rwId);

    final docSnap = await rwRef.get();
    if (docSnap.exists) {
      final createdAtRaw = (docSnap.data()!['createdAt'] as Timestamp).toDate();
      if (createdAtRaw.isBefore(startOfDay) && !widget.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tylko administrator może edytować.')),
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
      createdBy = data['createdBy'] ?? createdBy;
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

    if (!existsToday) {
      rwData['createdAt'] = FieldValue.serverTimestamp();
      rwData['createdBy'] = user.uid;
    } else {
      rwData['lastUpdatedAt'] = FieldValue.serverTimestamp();
      rwData['lastUpdatedBy'] = user.uid;
    }

    // Debug log of diffs
    for (var ln in filteredLines) {
      ln.previousQty ??= 0;
      debugPrint(
        '   • ${ln.itemRef}: requestedQty=${ln.requestedQty}, previousQty=${ln.previousQty}',
      );
    }

    // === DELETE-ALL
    if (filteredLines.isEmpty && docSnap.exists) {
      for (final ln in fullLines.where((l) => l.previousQty! > 0)) {
        try {
          await StockService.increaseQty(ln.itemRef, ln.previousQty!);
          debugPrint('🔄 Restored ${ln.previousQty} for ${ln.itemRef}');
        } catch (e) {
          debugPrint('⚠️ Couldn\'t restore ${ln.itemRef}: $e');
        }
      }

      final custSnap2 = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .get();
      final customerName2 = custSnap2.data()?['name'] as String? ?? '–';

      final projSnap2 = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final projectName2 = projSnap2.data()?['title'] as String? ?? '–';

      for (final ln in fullLines.where((l) => l.previousQty! > 0)) {
        final stock = _stockItems.firstWhere((s) => s.id == ln.itemRef);
        final name = stock.name;
        final changeText = '-${ln.previousQty}${ln.unit}';

        await AuditService.logAction(
          action: 'Usunięto RW',
          customerId: widget.customerId,
          projectId: widget.projectId,
          details: {
            '•': customerName2,
            '•': projectName2,
            '•': name,
            '•': changeText,
          },
        );
      }

      await rwRef.delete();
      debugPrint('🗑️ RW document $rwId deleted (no products)');

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

    // === CREATE/UPDATE branch ===
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var ln in filteredLines) {
        final prev = ln.previousQty ?? 0;
        final diff = ln.requestedQty - prev;
        if (diff != 0) {
          final stockRef = FirebaseFirestore.instance
              .collection('stock_items')
              .doc(ln.itemRef);
          batch.update(stockRef, {'quantity': FieldValue.increment(-diff)});
        }
      }

      if (existsToday) {
        batch.update(rwRef, rwData);
      } else {
        batch.set(rwRef, rwData);
      }

      await batch.commit();

      final movedLines = filteredLines.where((ln) {
        final prev = ln.previousQty ?? 0;
        return ln.requestedQty - prev != 0;
      });

      for (final ln in movedLines) {
        final prev = ln.previousQty ?? 0;
        final diff = ln.requestedQty - prev;
        final name = ln.isStock
            ? _stockItems.firstWhere((s) => s.id == ln.itemRef).name
            : ln.customName;
        final changeText = '${diff > 0 ? '+' : ''}$diff${ln.unit}';

        await AuditService.logAction(
          action: existsToday ? 'Zaktualizowano RW' : 'Utworzono RW',
          customerId: widget.customerId!,
          projectId: widget.projectId!,
          details: {'Produkt': name, 'Zmiana': changeText},
        );
      }

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

      await _checkTodayExists(type);
    } catch (e, st) {
      debugPrint('🔥 _saveRWDocument failed: $e\n$st');
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

  Future<void> _deleteLineFromRW(ProjectLine line) async {
    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwCol = projectRef.collection('rw_documents');

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final tomorrow = startOfDay.add(Duration(days: 1));

    final todaySnap = await rwCol
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: tomorrow)
        .limit(1)
        .get();

    if (todaySnap.docs.isEmpty) {
      return;
    }

    final rwDoc = todaySnap.docs.first;
    final rwId = rwDoc.id;
    final data = rwDoc.data();
    final materials = List<Map<String, dynamic>>.from(data['items'] ?? []);

    final updated = materials.where((m) {
      if (line.isStock) return m['itemId'] != line.itemRef;
      return m['name'] != line.customName;
    }).toList();

    // 3) restore stock
    if (line.isStock) {
      final stockRef = FirebaseFirestore.instance
          .collection('stock_items')
          .doc(line.itemRef);
      await stockRef.update({
        'quantity': FieldValue.increment(line.requestedQty),
      });
    }

    final stockName = line.isStock
        ? _stockItems.firstWhere((s) => s.id == line.itemRef).name
        : line.customName;
    await AuditService.logAction(
      action: 'Usunięto produkt',
      customerId: widget.customerId,
      projectId: widget.projectId,
      details: {
        'Produkt': stockName,
        'Zmiana': '-${line.requestedQty}${line.unit}',
      },
    );

    if (updated.isEmpty) {
      await rwCol.doc(rwId).delete();

      await AuditService.logAction(
        action: 'Usunięto RW',
        customerId: widget.customerId,
        projectId: widget.projectId,
        details: {'RWId': rwId},
      );

      setState(() => _rwExistsToday = false);
    } else {
      await rwCol.doc(rwId).update({'items': updated});
    }

    final projSnap = await projectRef.get();
    if (projSnap.exists) {
      final projItems = List<Map<String, dynamic>>.from(
        projSnap.data()?['items'] ?? [],
      );
      final newProjItems = projItems.where((m) {
        if (line.isStock) return m['itemId'] != line.itemRef;
        return m['name'] != line.customName;
      }).toList();
      await projectRef.update({'items': newProjItems});
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
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RWDocumentsScreen(
                    customerId: widget.customerId,
                    projectId: widget.projectId,
                    isAdmin: widget.isAdmin,
                  ),
                ),
              );
              if (!mounted) return;
              await _loadAll();
              await _checkTodayExists('RW');
              setState(() {});
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
                    content: Text('Potwierdź usunięcie projekt.'),
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

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  SizedBox(height: 16),

                  // photos & notes
                  PhotoGallery(
                    imageUrls: _photoUrls,
                    onAddImage: () async {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file == null) return null;

                      final downloadUrl =
                          await MyStorageService.uploadProjectImage(file);
                      // 3) persist to Firestore:
                      await projRef.update({
                        'images': FieldValue.arrayUnion([downloadUrl]),
                      });
                      return downloadUrl;
                    },
                  ),

                  SizedBox(height: 24),

                  NotesSection(
                    notes: _notesList,
                    onAddNote: (ctx) async {
                      String draft = '';
                      final result = await showDialog<String>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: Text('Nowa notatka'),
                          content: TextField(
                            onChanged: (v) => draft = v,
                            maxLines: 4,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx),
                              child: Text('Anuluj'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dctx, draft),
                              child: Text('Zapisz'),
                            ),
                          ],
                        ),
                      );
                      if (result == null || result.trim().isEmpty) return null;

                      final user = FirebaseAuth.instance.currentUser!;
                      final displayName = user.displayName ?? user.email ?? '…';
                      final now = DateTime.now();

                      final noteMap = {
                        'text': result.trim(),
                        'userName': displayName,
                        'createdAt': FieldValue.serverTimestamp(),
                      };

                      await projRef.update({
                        'notesList': FieldValue.arrayUnion([noteMap]),
                      });
                      return Note(
                        text: result.trim(),
                        userName: displayName,
                        createdAt: now,
                      );
                    },
                  ),
                  SizedBox(height: 24),

                  if (_lines.any(
                    (l) =>
                        l.requestedQty > 0 && l.requestedQty != l.previousQty,
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
                              _rwLocked || (!isToday && !widget.isAdmin);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            title: Text(name),
                            subtitle: Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: [
                                  TextSpan(
                                    text: '${ln.requestedQty} ${ln.unit} ',
                                  ),
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
                                if (isSynced)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Zapisany do RW',
                                      style: TextStyle(
                                        color: Colors.green[900],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: isLineLocked
                                        ? Colors.grey
                                        : Colors.blue,
                                  ),
                                  onPressed: isLineLocked
                                      ? () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Tylko administrator może edytować',
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
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: isLineLocked
                                        ? Colors.grey
                                        : Colors.red,
                                  ),
                                  onPressed: isLineLocked
                                      ? () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Tylko administrator może usuwać',
                                              ),
                                            ),
                                          );
                                        }
                                      : () async {
                                          final removedLine = _lines.removeAt(
                                            i,
                                          );
                                          setState(() {});

                                          await _deleteLineFromRW(removedLine);
                                        },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (!_rwLocked)
            Positioned(
              right: 16,
              bottom: kBottomNavigationBarHeight + 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: StadiumBorder(),
                  elevation: 4,
                ),
                onPressed:
                    (_rwExistsToday || _lines.any((l) => l.requestedQty > 0))
                    ? () => _saveRWDocument('RW')
                    : null,
                child: Text(_rwExistsToday ? 'Update RW' : 'Zapisz RW'),
              ),
            ),
        ],
      ),

      floatingActionButton: _rwLocked
          ? null
          : FloatingActionButton(
              tooltip: 'Dodaj pozycja',
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
                    const SnackBar(
                      content: Text('Nie można dodać bo pozycja już istnieje!'),
                    ),
                  );
                  return;
                }

                setState(() => _lines.add(lineWithUnit));
              },
              child: const Icon(Icons.playlist_add, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Inwentaryzacja',
                icon: const Icon(Icons.inventory_2),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        InventoryListScreen(isAdmin: widget.isAdmin),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Skanuj',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
