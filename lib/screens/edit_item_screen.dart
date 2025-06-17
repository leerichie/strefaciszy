// lib/screens/edit_item_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditItemScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const EditItemScreen(this.docId, {super.key, required this.data});

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl,
      _skuCtrl,
      _categoryCtrl,
      _barcodeCtrl,
      _quantityCtrl,
      _locationCtrl,
      _producerCtrl;

  String? _imageUrl;
  String _unit = 'szt';
  bool _saving = false, _uploading = false;
  String? _error;

  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance.ref();

  // ← new state for categories
  late StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    final d = widget.data;

    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _skuCtrl = TextEditingController(text: d['sku'] as String? ?? '');
    _categoryCtrl = TextEditingController(text: d['category'] as String? ?? '');
    _barcodeCtrl = TextEditingController(text: d['barcode'] as String? ?? '');
    _quantityCtrl = TextEditingController(text: '${d['quantity'] ?? 0}');
    _unit = d['unit'] as String? ?? 'szt';
    _locationCtrl = TextEditingController(text: d['location'] as String? ?? '');
    _imageUrl = d['imageUrl'] as String?;
    _producerCtrl = TextEditingController(
      text: widget.data['producent'] as String? ?? '',
    );

    // ← subscribe to Firestore 'categories' collection
    _catSub = FirebaseFirestore.instance
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _categories = snap.docs
                .map((doc) => doc['name'] as String)
                .toList();
          });
        });
  }

  @override
  void dispose() {
    _catSub.cancel();
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    _producerCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    String? newName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nowa kategoria'),
        content: TextField(
          decoration: InputDecoration(labelText: 'Nazwa'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newName != null && newName!.isNotEmpty) {
                FirebaseFirestore.instance.collection('categories').add({
                  'name': newName,
                });
                setState(() => _categoryCtrl.text = newName!);
              }
              Navigator.pop(ctx);
            },
            child: Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final ref = _storage.child('stock_images/${widget.docId}.jpg');

      if (kIsWeb) {
        final bytes = await x.readAsBytes();
        await ref.putData(bytes);
      } else {
        final file = File(x.path);
        await ref.putFile(file);
      }

      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('stock_items')
          .doc(widget.docId)
          .update({
            'imageUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          });

      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        _uploading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('stock_items')
          .doc(widget.docId)
          .update({
            'name': _nameCtrl.text.trim(),
            'producent': _producerCtrl.text.trim(),
            'sku': _skuCtrl.text.trim(),
            'category': _categoryCtrl.text.trim(),
            'barcode': _barcodeCtrl.text.trim(),
            'quantity': int.parse(_quantityCtrl.text.trim()),
            'unit': _unit,
            'location': _locationCtrl.text.trim(),
            'imageUrl': _imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          });
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Save failed: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edytuj produkt')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _saving
            ? Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: Colors.red)),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(labelText: 'Nazwa'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _producerCtrl,
                      decoration: const InputDecoration(labelText: 'Producent'),
                    ),
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Kategoria'),
                            value: _categoryCtrl.text.isNotEmpty
                                ? _categoryCtrl.text
                                : null,
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat[0].toUpperCase() + cat.substring(1),
                                ),
                              );
                            }).toList(),
                            onChanged: (cat) =>
                                setState(() => _categoryCtrl.text = cat!),
                            validator: (cat) =>
                                cat == null ? 'Wybierz kategoria' : null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          tooltip: 'Nowa kategori',
                          onPressed: _addCategory,
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(labelText: 'Kod kreskowy'),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Wpisz ilość' : null,
                    ),
                    SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: InputDecoration(labelText: 'Jm.'),
                      items: ['szt', 'm', 'kg', 'kpl']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    SizedBox(height: 12),

                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(labelText: 'Magazyn'),
                    ),
                    SizedBox(height: 12),

                    if (_uploading) Center(child: CircularProgressIndicator()),
                    if (_imageUrl != null)
                      Image.network(_imageUrl!, height: 150),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Zapisz fotka'),
                      onPressed: _changePhoto,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text('Zapisz'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
