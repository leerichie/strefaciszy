// lib/screens/project_editor_screen.dart

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scan_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' show basename;
import 'package:strefa_ciszy/models/rw_document.dart';
import 'package:strefa_ciszy/models/stock_item.dart';

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
  String? _previewRwDocId;

  List<StockItem> _stockItems = [];
  List<ProjectLine> _lines = [];

  String get _previewNotes {
    final lines = _notes.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 4) return lines.join('\n');
    return '${lines.take(4).join('\n')}\n…';
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _persistProject() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    await projRef.update({
      'items': _lines.map((l) => l.toMap()).toList(),
      'notes': _notes,
      'images': await Future.wait(
        _images.map((img) async {
          if (img.path.startsWith('http')) return img.path;
          final fileName = basename(img.path);
          final ref = FirebaseStorage.instance.ref(
            'project_images/${widget.projectId}/$fileName',
          );
          final task = await ref.putFile(File(img.path));
          return task.ref.getDownloadURL();
        }),
      ),
    });
  }

  Future<void> _saveRWDocument(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final itemsData = _lines.map((ln) {
      if (ln.isStock) {
        final stock = _stockItems.firstWhere((s) => s.id == ln.itemRef);
        return {
          'itemId': ln.itemRef,
          'name': stock.name,
          'quantity': ln.requestedQty,
          'unit': ln.unit,
        };
      } else {
        return {
          'itemId': null,
          'name': ln.customName,
          'quantity': ln.requestedQty,
          'unit': ln.unit,
        };
      }
    }).toList();

    final data = {
      'type': type,
      'projectId': widget.projectId,
      'projectName': _title,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'preview',
      'items': itemsData,
    };

    final docRef = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('rw_documents')
        .add(data);

    setState(() => _previewRwDocId = docRef.id);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Zapisany jako $type (preview)')));
  }

  Future<void> _loadAll() async {
    final stockSnap = await FirebaseFirestore.instance
        .collection('stock_items')
        .get();
    _stockItems = stockSnap.docs
        .map((d) => StockItem.fromMap(d.data(), d.id))
        .toList();

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

  Future<void> _openNotes() async {
    String draft = _notes;
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj notatki'),
        content: TextFormField(
          initialValue: draft,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Edytuj wszystkie notatki…',
          ),
          onChanged: (v) => draft = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, draft.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    if (updated != null) {
      setState(() => _notes = updated);
      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .collection('projects')
            .doc(widget.projectId)
            .update({'notes': _notes});
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd zapisu notatek: $e')));
      }
    }
  }

  Future<void> _openGallery() async {
    final picked = await _picker.pickMultiImage();
    if (picked == null || picked.isEmpty) return;
    setState(() => _images.addAll(picked));

    // upload new images only
    final storage = FirebaseStorage.instance;
    final List<String> newUrls = [];
    for (final img in picked) {
      final fileName = basename(img.path);
      final ref = storage.ref('project_images/${widget.projectId}/$fileName');
      try {
        final task = await ref.putFile(File(img.path));
        final url = await task.ref.getDownloadURL();
        newUrls.add(url);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd uploadu zdjęcia: $e')));
      }
    }

    if (newUrls.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .collection('projects')
            .doc(widget.projectId)
            .update({'images': FieldValue.arrayUnion(newUrls)});
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd zapisu obrazów: $e')));
      }
    }
  }

  Future<ProjectLine?> _openLineDialog({ProjectLine? existing}) async {
    bool isStock = existing?.isStock ?? true;
    String itemRef = existing?.itemRef ?? '';
    String custom = existing?.customName ?? '';
    int qty = existing?.requestedQty ?? 0;
    String unit = existing?.unit ?? 'szt';
    final formKey = GlobalKey<FormState>();

    final searchController = TextEditingController(
      text: isStock && itemRef.isNotEmpty
          ? _stockItems.firstWhere((s) => s.id == itemRef).name
          : '',
    );

    return showDialog<ProjectLine>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final query = searchController.text;
          final filtered = _stockItems
              .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
              .toList();

          return AlertDialog(
            title: Text(existing == null ? 'Dodaj' : 'Edytuj'),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1) Type selector
                    DropdownButtonFormField<bool>(
                      value: isStock,
                      decoration: const InputDecoration(labelText: 'Produkt'),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('W Magazynie'),
                        ),
                        DropdownMenuItem(value: false, child: Text('Custom')),
                      ],
                      onChanged: (v) => setState(() => isStock = v!),
                    ),

                    const SizedBox(height: 8),

                    // 2a) STOCK ITEM with scanner icon
                    if (isStock) ...[
                      TextFormField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText: itemRef.isEmpty
                              ? 'Szukaj produkt'
                              : 'Wybrany produkt',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              final rawCode = await Navigator.of(context)
                                  .push<String>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ScanScreen(returnCode: true),
                                    ),
                                  );
                              if (rawCode != null) {
                                final snap = await FirebaseFirestore.instance
                                    .collection('stock_items')
                                    .where('barcode', isEqualTo: rawCode)
                                    .limit(1)
                                    .get();
                                if (snap.docs.isNotEmpty) {
                                  final doc = snap.docs.first;
                                  final s = StockItem.fromMap(
                                    doc.data()! as Map<String, dynamic>,
                                    doc.id,
                                  );
                                  setState(() {
                                    itemRef = s.id;
                                    searchController.text = s.name;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Produkt o kodzie $rawCode nie znaleziony',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        onChanged: (v) {
                          // Always clear any previous selection and rebuild
                          setState(() {
                            itemRef = '';
                          });
                        },
                        validator: (v) {
                          if (isStock && itemRef.isEmpty) {
                            return 'Wybierz produkt';
                          }
                          return null;
                        },
                      ),

                      // Live suggestions when typing
                      if (searchController.text.isNotEmpty &&
                          itemRef.isEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final s = filtered[i];
                              return ListTile(
                                title: Text(s.name),
                                subtitle: Text('Stan: ${s.quantity} ${s.unit}'),
                                onTap: () {
                                  setState(() {
                                    itemRef = s.id;
                                    searchController.text = s.name;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ]
                    // 2b) CUSTOM
                    else
                      TextFormField(
                        initialValue: custom,
                        decoration: const InputDecoration(
                          labelText: 'Własny prod.',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        onChanged: (v) => custom = v,
                      ),

                    const SizedBox(height: 8),

                    // 3) Quantity
                    TextFormField(
                      initialValue: qty.toString(),
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return (n == null || n < 0) ? 'Invalid' : null;
                      },
                      onChanged: (v) => qty = int.tryParse(v) ?? qty,
                    ),

                    const SizedBox(height: 8),

                    // 4) Unit
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'jm.'),
                      items: ['szt', 'm', 'kg', 'kpl']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => unit = v ?? unit,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Anuluj'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(ctx).pop(
                    ProjectLine(
                      isStock: isStock,
                      itemRef: itemRef,
                      customName: isStock ? '' : custom,
                      requestedQty: qty,
                      unit: unit,
                    ),
                  );
                },
                child: Text(existing == null ? 'Dodaj' : 'Zapisz'),
              ),
            ],
          );
        },
      ),
    );
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

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final storage = FirebaseStorage.instance;
    final List<String> urls = [];
    for (final img in _images) {
      if (img.path.startsWith('http')) {
        urls.add(img.path);
      } else {
        final fileName = basename(img.path);
        final ref = storage.ref('project_images/${widget.projectId}/$fileName');
        final uploadTask = await ref.putFile(File(img.path));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        urls.add(downloadUrl);
      }
    }

    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    await projRef.update({
      'title': _title,
      'status': 'draft',
      'items': _lines.map((l) => l.toMap()).toList(),
      'notes': _notes,
      'images': urls,
    });

    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  Future<void> _confirmProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_previewRwDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Najpierw zapisz RW/M—potem zatwierdź.')),
      );
      return;
    }
    setState(() => _saving = true);

    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwRef = db
        .collection('customers')
        .doc(widget.customerId)
        .collection('rw_documents')
        .doc(_previewRwDocId);

    try {
      await db.runTransaction((tx) async {
        for (final ln in _lines.where((l) => l.isStock)) {
          final stockRef = db.collection('stock_items').doc(ln.itemRef);
          final stockSnap = await tx.get(stockRef);
          final stockQty = (stockSnap.data()!['quantity'] ?? 0) as int;
          if (ln.requestedQty > stockQty) {
            throw Exception(
              "Not enough stock for ${stockSnap.data()!['name']}",
            );
          }
          tx.update(stockRef, {
            'quantity': stockQty - ln.requestedQty,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          });
        }

        tx.update(projRef, {'status': 'confirmed'});
      });

      await rwRef.update({
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projekt zatwierdzony, zapasy zaktualizowane'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

      body: Padding(
        padding: EdgeInsets.all(16),
        child: _saving
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _title,
                      decoration: InputDecoration(labelText: 'Projekt:'),
                      onChanged: (v) => _title = v,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16),

                    if (_lines.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          itemCount: _lines.length,
                          itemBuilder: (ctx, i) => _buildCompactRow(i),
                        ),
                      ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _addLine,
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(12),
                          elevation: 4,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ),

                    Divider(height: 32),

                    // … inside your Form’s Column …

                    // PREVIEW / ATTACHMENTS
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1) Bordered images row
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _openGallery,
                                child: const Icon(Icons.photo_library),
                              ),
                              if (_images.isNotEmpty) ...[
                                const SizedBox(width: 12),
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
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(path),
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                              );
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: thumb,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 2) Divider line
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.grey),
                        const SizedBox(height: 16),

                        // 3) Bordered notes area
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _openNotes,
                                child: const Icon(Icons.note_add),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _openNotes,
                                  child: Text(
                                    _notes.isNotEmpty
                                        ? _notes
                                        : 'Dodaj notatke',
                                    maxLines: 5,
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
                        ),
                      ],
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _saveRWDocument('RW'),
                      child: const Text('Zapisz RW'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _saveRWDocument('MM'),
                      child: const Text('Zapisz MM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveDraft,
                      child: const Text('Wersja Robocza'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmProject,
                      child: const Text('Zatwierdź'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final totalStock = ln.isStock ? stockItem.quantity : 0;
    final remaining = totalStock - qty;
    final enough = remaining > 0;

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
  bool isStock;
  String itemRef;
  String customName;
  int requestedQty;
  String unit;

  ProjectLine({
    this.isStock = true,
    this.itemRef = '',
    this.customName = '',
    this.requestedQty = 0,
    this.unit = 'szt',
  });

  factory ProjectLine.fromMap(Map<String, dynamic> m) => ProjectLine(
    isStock: m.containsKey('itemRef'),
    itemRef: m['itemRef'] as String? ?? '',
    customName: m['customName'] as String? ?? '',
    requestedQty: m['requestedQty'] as int? ?? 0,
    unit: m['unit'] as String? ?? 'szt',
  );

  Map<String, dynamic> toMap() {
    final map = {'requestedQty': requestedQty, 'unit': unit};
    if (isStock) {
      map['itemRef'] = itemRef;
    } else {
      map['customName'] = customName;
    }
    return map;
  }
}
