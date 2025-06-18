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
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/models/rw_document.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/stock_service.dart';

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

  setState(() => _saving = true);
  final rwId = FirebaseFirestore.instance.collection('rw_documents').doc().id;
  final rwMap = StockService.buildRwDocMap( … );

  try {
    await StockService.applyProjectLinesTransaction( … );
    ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Zapisano $type i zaktualizowano magazyn')));
    await _loadAll();
  } catch (e) {
    ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
  } finally {
    setState(() => _saving = false);
  }
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
