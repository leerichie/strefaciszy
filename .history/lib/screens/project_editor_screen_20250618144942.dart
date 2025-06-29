// lib/screens/project_editor_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/models/project_line.dart';
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
    // Listen to stock items
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
  }

  @override
  void dispose() {
    _stockSub.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final snap = await projRef.get();
    final data = snap.data()!;

    _title = data['title'] as String? ?? '';
    _status = data['status'] as String? ?? 'draft';
    _notes = data['notes'] as String? ?? '';
    _images = (data['images'] as List<dynamic>? ?? [])
        .cast<String>()
        .map((u) => XFile(u))
        .toList();
    _lines = (data['items'] as List<dynamic>? ?? [])
        .map((m) => ProjectLine.fromMap(m as Map<String, dynamic>))
        .toList();

    setState(() {
      _loading = false;
      _initialized = true;
    });
  }

  Future<void> _saveRWDocument(String type) async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    final rwId = FirebaseFirestore.instance.collection('rw_documents').doc().id;
    final rwData = StockService.buildRwDocMap(
      rwId,
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
        rwDocId: rwId,
        rwDocData: rwData,
        lines: _lines,
        newStatus: type,
        userId: user.uid,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zapisano $type - magazyn aktualny')),
      );
      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
      Navigator.of(context).pop();
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
        actions: widget.isAdmin
            ? [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
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
              ]
            : null,
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

              // Project lines list
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
                      final remaining = ln.originalStock - ln.requestedQty;

                      return ListTile(
                        title: Text(name),
                        subtitle: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              TextSpan(text: '${ln.requestedQty} ${ln.unit} '),
                              TextSpan(
                                text: '(stan: $remaining)',
                                style: TextStyle(color: Colors.green),
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
                              onPressed: () =>
                                  setState(() => _lines.removeAt(i)),
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

                    setState(() => _lines.add(newLine));
                  },
                  child: Icon(Icons.add),
                ),
              ),

              Divider(height: 32),

              // Images & notes preview omitted for brevity
              // Save buttons
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
