// lib/screens/project_editor_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' show basename;
import 'package:strefa_ciszy/models/rw_document.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class ProjectEditorScreen extends StatefulWidget {
  final bool isAdmin;
  final String customerId;
  final String projectId;

  const ProjectEditorScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
  });

  @override
  _ProjectEditorScreenState createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String _title = '';
  String _status = 'draft';
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];
  String _notes = '';
  bool _initialized = false;

  StreamSubscription<QuerySnapshot>? _stockSub;

  List<StockItem> _stockItems = [];
  List<ProjectLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _stockSub = FirebaseFirestore.instance
        .collection('stock_items')
        .snapshots()
        .listen((snap) {
          setState(() {
            _stockItems = snap.docs
                .map((d) => StockItem.fromMap(d.data(), d.id))
                .toList();
          });
        });
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAll();
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    super.dispose();
  }

  Future<void> _saveRWDocument(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final rwDocId = FirebaseFirestore.instance
        .collection('rw_documents')
        .doc()
        .id;
    final rwMap = StockService.buildRwDocMap(
      rwDocId,
      widget.projectId,
      _title,
      user.uid,
      DateTime.now(),
      type,
      _lines,
      _stockItems,
    );

    try {
      await StockService.applyProjectLinesTransaction(
        customerId: widget.customerId,
        projectId: widget.projectId,
        rwDocId: rwDocId,
        rwDocData: rwMap,
        lines: _lines,
        newStatus: type,
        userId: user.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zapisano $type i zaktualizowano magazyn')),
      );
      await _loadAll(); // reload local state
      setState(() {}); // refresh preview
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  RWDocument _buildRWDocument(String id, String type, String userId) {
    return RWDocument(
      id: id,
      projectId: widget.projectId,
      projectName: _title,
      createdBy: userId,
      createdAt: DateTime.now(),
      type: type,
      items: _lines
          .map(
            (l) => {
              'itemId': l.itemRef,
              'name': l.isStock
                  ? _stockItems.firstWhere((s) => s.id == l.itemRef).name
                  : l.customName,
              'quantity': l.requestedQty,
              'unit': l.unit,
            },
          )
          .toList(),
    );
  }

  Future<void> _runSaveTransaction({
    required FirebaseFirestore db,
    required String userId,
    required List<ProjectLine> lines,
    required DocumentReference rwRef,
    required RWDocument rwDoc,
    required DocumentReference projectRef,
    required String newStatus,
  }) {
    return db.runTransaction((tx) async {
      // 1) Adjust stock for each stock line
      for (final ln in lines.where((l) => l.isStock)) {
        await _updateStockLine(tx, userId, ln);
      }

      // 2) Create the RW document
      tx.set(rwRef, rwDoc.toMap());

      // 3) Save updated project items + status
      tx.update(projectRef, {
        'items': lines.map((l) => l.toMap()).toList(),
        'status': newStatus,
      });
    });
  }

  Future<void> _updateStockLine(
    Transaction tx,
    String userId,
    ProjectLine ln,
  ) async {
    final stockRef = FirebaseFirestore.instance
        .collection('stock_items')
        .doc(ln.itemRef);
    final stockSnap = await tx.get(stockRef);
    final data = stockSnap.data()!;
    final currentQty = data['quantity'] as int;
    final delta = ln.requestedQty - ln.previousQty;

    if (delta > 0 && delta > currentQty) {
      throw Exception('Za mało ${data['name']}');
    }

    tx.update(stockRef, {
      'quantity': currentQty - delta,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });

    ln.previousQty = ln.requestedQty;
  }

  Future<void> _loadAll() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final projSnap = await projRef.get();
    final projData = projSnap.data()!;

    _title = projData['title'] as String? ?? '';
    _status = projData['status'] as String? ?? 'draft';
    _notes = projData['notes'] as String? ?? '';

    final urls = (projData['images'] as List<dynamic>?)?.cast<String>() ?? [];
    _images = urls.map((u) => XFile(u)).toList();

    final items = (projData['items'] as List<dynamic>?) ?? [];
    _lines = items.map((e) => ProjectLine.fromMap(e)).toList();

    setState(() => _loading = false);
  }

  Future<void> _openGallery() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  Future<void> _openNotes() async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String draft = _notes;
        return AlertDialog(
          title: Text('Edytuj Notatki'),
          content: TextFormField(
            initialValue: draft,
            maxLines: 5,
            onChanged: (v) => draft = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
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
    if (text != null) setState(() => _notes = text);
  }

  Future<ProjectLine?> _openLineDialog({ProjectLine? existing}) async {
    // 1) Local editable state
    bool isStock = existing?.isStock ?? true;
    String itemRef = existing?.itemRef ?? '';
    final customController = TextEditingController(
      text: existing?.customName ?? '',
    );
    int qty = existing?.requestedQty ?? 0;
    String unit = existing?.unit ?? 'szt';
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<ProjectLine>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ▲ Title
                      Text(
                        existing == null ? 'Dodaj' : 'Edytuj',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),

                      // 1) Stock vs. Custom selector
                      DropdownButtonFormField<bool>(
                        value: isStock,
                        decoration: InputDecoration(labelText: 'Produkt'),
                        items: [
                          DropdownMenuItem(
                            value: true,
                            child: Text('W Magazynie'),
                          ),
                          DropdownMenuItem(value: false, child: Text('Custom')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            isStock = v;
                            itemRef = '';
                            customController.clear();
                          });
                        },
                      ),
                      SizedBox(height: 12),

                      // 2a) Autocomplete for stock items
                      if (isStock)
                        Autocomplete<StockItem>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final query = textEditingValue.text.toLowerCase();
                            if (query.isEmpty) return const <StockItem>[];
                            return _stockItems.where(
                              (s) => s.name.toLowerCase().contains(query),
                            );
                          },
                          displayStringForOption: (s) => s.name,
                          onSelected: (selection) {
                            setState(() {
                              itemRef = selection.id;
                            });
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textController,
                                focusNode,
                                onSubmitted,
                              ) {
                                // initialize from existing
                                if (existing != null &&
                                    existing.isStock &&
                                    textController.text.isEmpty) {
                                  final name = _stockItems
                                      .firstWhere((s) => s.id == itemRef)
                                      .name;
                                  textController.text = name;
                                  textController.selection =
                                      TextSelection.collapsed(
                                        offset: name.length,
                                      );
                                }
                                return TextFormField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Szukaj produkt',
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.qr_code_scanner),
                                      onPressed: () async {
                                        final code = await Navigator.of(context)
                                            .push<String>(
                                              MaterialPageRoute(
                                                builder: (_) => ScanScreen(
                                                  returnCode: true,
                                                ),
                                                fullscreenDialog: true,
                                              ),
                                            );
                                        if (code?.isNotEmpty ?? false) {
                                          final querySnap =
                                              await FirebaseFirestore.instance
                                                  .collection('stock_items')
                                                  .where(
                                                    'barcode',
                                                    isEqualTo: code,
                                                  )
                                                  .limit(1)
                                                  .get();
                                          if (querySnap.docs.isNotEmpty) {
                                            final doc = querySnap.docs.first;
                                            final data = doc.data();
                                            setState(() {
                                              itemRef = doc.id;
                                              textController.text =
                                                  data['name'] as String;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Nie znaleziono produktu: $code',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => isStock && itemRef.isEmpty
                                      ? 'Wybierz produkt.'
                                      : null,
                                );
                              },
                        ),

                      // 2b) Custom-name field
                      if (!isStock)
                        TextFormField(
                          controller: customController,
                          decoration: InputDecoration(
                            labelText: 'Nazwa custom',
                          ),
                          validator: (v) {
                            if (!isStock && (v == null || v.trim().isEmpty)) {
                              return 'Wprowadź nazwę.';
                            }
                            return null;
                          },
                          onChanged: (v) => setState(() {}),
                        ),

                      SizedBox(height: 12),

                      // 3) Quantity
                      TextFormField(
                        initialValue: qty.toString(),
                        decoration: InputDecoration(labelText: 'Ilość'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                        onChanged: (v) => qty = int.tryParse(v) ?? qty,
                      ),

                      SizedBox(height: 12),

                      // 4) Unit
                      DropdownButtonFormField<String>(
                        value: unit,
                        decoration: InputDecoration(labelText: 'jm.'),
                        items: ['szt', 'm', 'kg', 'kpl']
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => unit = v ?? unit),
                      ),

                      SizedBox(height: 24),

                      // 5) Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: Text('Anuluj'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              if (isStock && itemRef.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Wybierz produkt.')),
                                );
                                return;
                              }

                              // determine originalStock & previousQty
                              final chosenStock = isStock
                                  ? _stockItems.firstWhere(
                                      (s) => s.id == itemRef,
                                    )
                                  : StockItem(
                                      id: '',
                                      name: customController.text.trim(),
                                      unit: unit,
                                      quantity: 0,
                                    );

                              final newLine = ProjectLine(
                                isStock: isStock,
                                itemRef: itemRef,
                                customName: isStock
                                    ? ''
                                    : customController.text.trim(),
                                requestedQty: qty,
                                unit: unit,
                                originalStock: chosenStock.quantity,
                                previousQty:
                                    existing?.previousQty ??
                                    chosenStock.quantity,
                              );

                              Navigator.of(ctx).pop(newLine);
                            },
                            child: Text(existing == null ? 'Dodaj' : 'Zapisz'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _updateStockLine(
    Transaction tx,
    String userId,
    ProjectLine ln,
  ) async {
    final stockRef = FirebaseFirestore.instance
        .collection('stock_items')
        .doc(ln.itemRef);
    final stockSnap = await tx.get(stockRef);
    final data = stockSnap.data()!;
    final currentQty = data['quantity'] as int;

    // compute how much the *reservation* changed:
    final delta = ln.requestedQty - ln.previousQty;

    if (delta > 0) {
      // user increased the request → subtract that extra
      if (delta > currentQty) {
        throw Exception('Za mało ${data['name']}');
      }
      tx.update(stockRef, {
        'quantity': currentQty - delta,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    } else if (delta < 0) {
      // user *decreased* the request → return the excess back to stock
      tx.update(stockRef, {
        'quantity': currentQty + (-delta),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    } // else delta == 0 → no change

    // update our in-memory marker so future edits compare correctly
    ln.previousQty = ln.requestedQty;
  }

  Future<void> _addLine() async {
    final newLine = await _openLineDialog();
    if (newLine != null) setState(() => _lines.add(newLine));
  }

  Future<void> _editLine(int index) async {
    final updated = await _openLineDialog(existing: _lines[index]);
    if (updated != null) setState(() => _lines[index] = updated);
  }

  void _removeLine(int index) => setState(() => _lines.removeAt(index));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Ładowanie...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final projectStream = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edytuj projekt'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Usuń projekt?'),
                    content: Text('Czy na pewno chcesz usunąć ten projekt?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
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
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),

      // 2️⃣ StreamBuilder around the body:
      body: StreamBuilder<DocumentSnapshot>(
        stream: projectStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData || snap.data!.data() == null) {
            return Center(child: Text('Błąd ładowania projektu.'));
          }

          // 3️⃣ Pull fresh data into your local state:
          if (!_initialized) {
            _initialized = true;
            final data = snap.data!.data()! as Map<String, dynamic>;
            _title = data['title'] as String? ?? '';
            _status = data['status'] as String? ?? 'draft';
            _notes = data['notes'] as String? ?? '';

            final urls =
                (data['images'] as List<dynamic>?)?.cast<String>() ?? [];
            _images = urls.map((u) => XFile(u)).toList();

            final items = (data['items'] as List<dynamic>?) ?? [];
            _lines = items.map((e) => ProjectLine.fromMap(e)).toList();
          }
          // 4️⃣ Build the rest of your editor UI (identical to your old body)
          return Padding(
            padding: EdgeInsets.all(16),
            child: _saving
                ? Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Title field
                        TextFormField(
                          initialValue: _title,
                          decoration: InputDecoration(labelText: 'Projekt:'),
                          onChanged: (v) => _title = v,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 16),

                        // ITEM list
                        if (_lines.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              itemCount: _lines.length,
                              itemBuilder: (ctx, i) => _buildCompactRow(i),
                            ),
                          ),

                        // Add ITEM
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _addLine,
                            style: ElevatedButton.styleFrom(
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(12),
                            ),
                            child: Icon(Icons.add, color: Colors.green),
                          ),
                        ),

                        Divider(height: 32),

                        // PREVIEW
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Images
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _openGallery,
                                  style: ElevatedButton.styleFrom(
                                    shape: CircleBorder(),
                                    padding: EdgeInsets.all(12),
                                    elevation: 4,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  child: Icon(
                                    Icons.photo_library,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_images.isNotEmpty) ...[
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _images.length,
                                        itemBuilder: (_, i) {
                                          final path = _images[i].path;
                                          final thumb = path.startsWith('http')
                                              ? Image.network(
                                                  path,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.contain,
                                                )
                                              : Image.file(
                                                  File(path),
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.contain,
                                                );

                                          return GestureDetector(
                                            onTap: _openGallery,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: thumb,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            SizedBox(height: 16),

                            // Notes
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _openNotes,
                                  style: ElevatedButton.styleFrom(
                                    shape: CircleBorder(),
                                    padding: EdgeInsets.all(12),
                                    elevation: 4,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  child: Icon(
                                    Icons.note_add,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _openNotes,
                                    child: Text(
                                      _notes.isNotEmpty
                                          ? _notes
                                          : 'Dodaj notatke',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontStyle: _notes.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 32),

                        // Save / Confirm buttons
                        // SafeArea(
                        //   top: false,
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        //     children: [
                        //       ElevatedButton(
                        //         onPressed: _saveDraft,
                        //         child: Text('Wersja Robocza'),
                        //       ),
                        //       ElevatedButton(
                        //         onPressed: _confirmProject,
                        //         child: Text('Zatwierdz'),
                        //       ),
                        //     ],
                        //   ),
                        // ),

                        // Save RW / MM buttons
                        SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => _saveRWDocument('RW'),
                                child: Text('Zapisz RW'),
                              ),
                              ElevatedButton(
                                onPressed: () => _saveRWDocument('MM'),
                                child: Text('Zapisz MM'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCompactRow(int index) {
    final ln = _lines[index];
    final stockItem = _stockItems.firstWhere(
      (s) => s.id == ln.itemRef,
      orElse: () => StockItem(id: '', name: 'Unknown', unit: '', quantity: 0),
    );

    final name = ln.isStock ? stockItem.name : ln.customName;

    final qty = ln.requestedQty;

    final totalStock = ln.isStock ? ln.originalStock : 0;
    final remaining = totalStock - qty;
    final enough = remaining >= 0;

    return ListTile(
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$qty ${ln.unit} '),
            TextSpan(
              text: '(stan: $remaining)',
              style: TextStyle(
                color: enough ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.edit), onPressed: () => _editLine(index)),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _removeLine(index),
          ),
        ],
      ),
    );
  }
}

class ProjectLine {
  final bool isStock;
  final String itemRef;
  final String customName;
  int requestedQty;
  final String unit;
  final int originalStock;
  int previousQty;

  ProjectLine({
    this.isStock = true,
    required this.itemRef,
    this.customName = '',
    required this.requestedQty,
    this.unit = 'szt',
    required this.originalStock,
    required this.previousQty,
  });

  factory ProjectLine.fromMap(Map<String, dynamic> m) {
    final rq = m['requestedQty'] as int? ?? 0;
    return ProjectLine(
      isStock: m.containsKey('itemRef'),
      itemRef: m['itemRef'] as String? ?? '',
      customName: m['customName'] as String? ?? '',
      requestedQty: rq,
      unit: m['unit'] as String? ?? 'szt',
      originalStock: m['originalStock'] as int? ?? rq,
      previousQty: m['previousQty'] as int? ?? rq,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'requestedQty': requestedQty,
      'unit': unit,
      'originalStock': originalStock,
      'previousQty': previousQty,
    };
    if (isStock) {
      map['itemRef'] = itemRef;
    } else {
      map['customName'] = customName;
    }
    return map;
  }
}
