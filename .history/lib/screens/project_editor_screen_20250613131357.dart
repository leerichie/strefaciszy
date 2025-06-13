// lib/screens/project_editor_screen.dart

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

  /// All stock items for the dropdown:
  List<StockItem> _stockItems = [];

  /// Our in‐memory draft lines:
  List<ProjectLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // 1) load stock_items
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

    // 2) load project doc
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
    _lines = items.map((e) {
      return ProjectLine.fromMap(e as Map<String, dynamic>);
    }).toList();

    // ensure at least one blank row:
    if (_lines.isEmpty) _lines.add(ProjectLine());

    setState(() => _loading = false);
  }

  void _addLine() {
    setState(() {
      _lines.add(ProjectLine());
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  /// Live preview: returns a widget list summarizing each line.
  List<Widget> _buildPreview() {
    return _lines.map((ln) {
      if (ln.isStock) {
        final stock = _stockItems.firstWhere((s) => s.id == ln.itemRef);
        final available = stock.quantity;
        final remaining = available - ln.requestedQty;
        return Text(
          '${stock.name}: $available ${stock.unit} → ${remaining < 0 ? 0 : remaining} ${stock.unit}',
        );
      } else {
        return Text('Order: ${ln.customName} – ${ln.requestedQty} ${ln.unit}');
      }
    }).toList();
  }

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
        // 1) re‐fetch each stock item
        for (final ln in _lines.where((l) => l.isStock)) {
          final stockRef = db.collection('stock_items').doc(ln.itemRef);
          final stockSnap = await tx.get(stockRef);
          final stockQty = (stockSnap.data()!['quantity'] ?? 0) as int;
          if (ln.requestedQty > stockQty) {
            throw Exception(
              'Not enough stock for ${stockSnap.data()!['name']}',
            );
          }
          tx.update(stockRef, {
            'quantity': stockQty - ln.requestedQty,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          });
        }

        // 2) update the project to confirmed
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
                    // — Title —
                    TextFormField(
                      initialValue: _title,
                      decoration: InputDecoration(labelText: 'Project Title'),
                      onChanged: (v) => _title = v,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16),

                    // — Line Items —
                    Expanded(
                      child: ListView.builder(
                        itemCount: _lines.length,
                        itemBuilder: (ctx, i) {
                          return _buildLineRow(i);
                        },
                      ),
                    ),

                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Line'),
                      onPressed: _addLine,
                    ),

                    Divider(height: 32),

                    // — Preview Panel —
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Preview:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ..._buildPreview(),

                    SizedBox(height: 24),

                    // — Actions —
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

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            // Mode toggle
            DropdownButton<bool>(
              value: line.isStock,
              items: [
                DropdownMenuItem(child: Text('Stock'), value: true),
                DropdownMenuItem(child: Text('Custom'), value: false),
              ],
              onChanged: (v) {
                setState(() {
                  line.isStock = v!;
                });
              },
            ),

            SizedBox(width: 8),

            // Stock dropdown vs custom text
            if (line.isStock)
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.itemRef,
                  items: _stockItems
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => line.itemRef = v!);
                  },
                  decoration: InputDecoration(labelText: 'Item'),
                ),
              )
            else
              Expanded(
                child: TextFormField(
                  initialValue: line.customName,
                  decoration: InputDecoration(labelText: 'Custom Name'),
                  onChanged: (v) => line.customName = v,
                  validator: (v) => (line.isStock || (v?.isNotEmpty ?? false))
                      ? null
                      : 'Required',
                ),
              ),

            SizedBox(width: 8),

            // Quantity
            SizedBox(
              width: 60,
              child: TextFormField(
                initialValue: '${line.requestedQty}',
                decoration: InputDecoration(labelText: 'Qty'),
                keyboardType: TextInputType.number,
                onChanged: (v) => line.requestedQty = int.tryParse(v) ?? 0,
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? -1) < 0 ? '0+' : null,
              ),
            ),

            SizedBox(width: 8),

            // Unit
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<String>(
                value: line.unit,
                items: ['szt', 'm', 'kg']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => line.unit = v!,
                decoration: InputDecoration(labelText: 'Unit'),
              ),
            ),

            SizedBox(width: 8),

            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeLine(index),
            ),
          ],
        ),
      ),
    );
  }
}

/// In-memory model for a single line in the project editor
class ProjectLine {
  bool isStock;
  String itemRef; // stock_items doc ID
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

/// Minimal stock‐item model
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
