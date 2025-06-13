// lib/screens/project_editor_screen.dart

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectEditorScreen extends StatefulWidget {
  final String customerId;
  final String projectId;

  const ProjectEditorScreen({
    Key? key,
    required this.customerId,
    required this.projectId,
  }) : super(key: key);

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

  List<StockItem> _stockItems = [];
  List<ProjectLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final stockSnap = await FirebaseFirestore.instance
        .collection('stock_items')
        .get();
    _stockItems = stockSnap.docs.map((d) {
      final m = d.data();
      return StockItem(
        id: d.id,
        name: m['name'] as String? ?? '—',
        unit: m['unit'] as String? ?? '',
        quantity: m['quantity'] as int? ?? 0,
      );
    }).toList();

    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final projSnap = await projRef.get();
    final projData = projSnap.data()!;

    _title = projData['title'] as String? ?? '';
    _status = projData['status'] as String? ?? 'draft';

    final items = (projData['items'] as List<dynamic>? ?? []);
    _lines = items
        .map((e) => ProjectLine.fromMap(e as Map<String, dynamic>))
        .toList();

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
          title: Text('Edit Notes'),
          content: TextFormField(
            initialValue: draft,
            maxLines: 5,
            onChanged: (v) => draft = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, draft),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
    if (text != null) setState(() => _notes = text);
  }

  Future<ProjectLine?> _openLineDialog({ProjectLine? existing}) async {
    bool isStock = existing?.isStock ?? true;
    String itemRef = existing?.itemRef ?? '';
    String customName = existing?.customName ?? '';
    int requestedQty = existing?.requestedQty ?? 0;
    String unit = existing?.unit ?? 'szt';
    final _dlgFormKey = GlobalKey<FormState>();

    return showDialog<ProjectLine>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Line' : 'Edit Line'),
        content: Form(
          key: _dlgFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<bool>(
                  value: isStock,
                  items: [
                    DropdownMenuItem(child: Text('Stock'), value: true),
                    DropdownMenuItem(child: Text('Custom'), value: false),
                  ],
                  onChanged: (v) => isStock = v!,
                  decoration: InputDecoration(labelText: 'Type'),
                ),
                SizedBox(height: 8),
                if (isStock)
                  DropdownButtonFormField<String>(
                    value: itemRef.isNotEmpty ? itemRef : null,
                    items: _stockItems
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => itemRef = v ?? '',
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                    decoration: InputDecoration(labelText: 'Item'),
                  )
                else
                  TextFormField(
                    initialValue: customName,
                    decoration: InputDecoration(labelText: 'Custom Name'),
                    onChanged: (v) => customName = v,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                SizedBox(height: 8),
                TextFormField(
                  initialValue: existing?.requestedQty.toString(),
                  decoration: InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => requestedQty = int.tryParse(v) ?? 0,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n < 0) ? 'Invalid' : null;
                  },
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: unit,
                  items: ['szt', 'm', 'kg']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => unit = v ?? unit,
                  decoration: InputDecoration(labelText: 'Unit'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_dlgFormKey.currentState!.validate()) {
                Navigator.of(ctx).pop(
                  ProjectLine(
                    isStock: isStock,
                    itemRef: isStock ? itemRef : '',
                    customName: isStock ? '' : customName,
                    requestedQty: requestedQty,
                    unit: unit,
                  ),
                );
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
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
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    await projRef.update({
      'title': _title,
      'status': 'draft',
      'items': _lines.map((l) => l.toMap()).toList(),
    });
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  Future<void> _confirmProject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
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
        tx.update(projRef, {
          'title': _title,
          'status': 'confirmed',
          'items': _lines.map((l) => l.toMap()).toList(),
        });
      });
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
        appBar: AppBar(title: Text('Loading…')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Edit Project')),
      body: Padding(
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

                    // Existing lines
                    if (_lines.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          itemCount: _lines.length,
                          itemBuilder: (ctx, i) => _buildCompactRow(i),
                        ),
                      ),

                    // Add-line button
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

                    // PREVIEW / ATTACHMENTS
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Images
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
                                  height: 48, // down from 64
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _images.length,
                                    itemBuilder: (_, i) => GestureDetector(
                                      onTap: _openGallery,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Image.file(
                                          File(_images[i].path),
                                          width: 48, // shrink to 48×48
                                          height: 48,
                                          fit: BoxFit.contain, // no cropping
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: 16),

                        // Row 2: Notes
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
                              child: Icon(Icons.note_add, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: _openNotes,
                                child: Text(
                                  _notes.isNotEmpty
                                      ? _notes
                                      : 'Tap to add notes',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _saveDraft,
                          child: Text('Save Draft'),
                        ),
                        ElevatedButton(
                          onPressed: _confirmProject,
                          child: Text('Confirm'),
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
    final name = ln.isStock
        ? _stockItems
              .firstWhere(
                (s) => s.id == ln.itemRef,
                orElse: () =>
                    StockItem(id: '', name: 'Unknown', unit: '', quantity: 0),
              )
              .name
        : ln.customName;
    final qty = ln.requestedQty;
    final totalStock = ln.isStock
        ? _stockItems
              .firstWhere(
                (s) => s.id == ln.itemRef,
                orElse: () =>
                    StockItem(id: '', name: '', unit: '', quantity: 0),
              )
              .quantity
        : 0;
    final remaining = totalStock - qty;
    final enough = !ln.isStock || remaining > 0;

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

class StockItem {
  final String id, name, unit;
  final int quantity;

  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
  });
}
