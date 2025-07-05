// lib/screens/edit_item_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:strefa_ciszy/screens/main_menu_screen.dart';

class EditItemScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const EditItemScreen(
    this.docId, {
    Key? key,
    required this.data,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _producerCtrl,
      _nameCtrl,
      _skuCtrl,
      _categoryCtrl,
      _barcodeCtrl,
      _quantityCtrl,
      _locationCtrl;

  String? _imageUrl;
  String _unit = 'szt';
  bool _saving = false, _uploading = false;
  String? _error;

  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance.ref();

  late StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    final d = widget.data;

    _producerCtrl = TextEditingController(
      text: d['producent'] as String? ?? '',
    );
    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _skuCtrl = TextEditingController(text: d['sku'] as String? ?? '');
    _categoryCtrl = TextEditingController(text: d['category'] as String? ?? '');
    _barcodeCtrl = TextEditingController(text: d['barcode'] as String? ?? '');
    _quantityCtrl = TextEditingController(text: '${d['quantity'] ?? 0}');
    _unit = d['unit'] as String? ?? 'szt';
    _locationCtrl = TextEditingController(text: d['location'] as String? ?? '');
    _imageUrl = d['imageUrl'] as String?;

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
    _producerCtrl.dispose();
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    String? newName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa kategoria'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Nazwa'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
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
            child: const Text('Dodaj'),
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
        await ref.putFile(File(x.path));
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
            'producent': _producerCtrl.text.trim(),
            'name': _nameCtrl.text.trim(),
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
    final canEdit = widget.isAdmin; // ← non-admins cannot edit

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Edytuj produkt'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              child: IconButton(
                icon: const Icon(Icons.home),
                color: Colors.white,
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const MainMenuScreen(role: 'admin'),
                    ),
                    (_) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),

                    TextFormField(
                      controller: _producerCtrl,
                      decoration: const InputDecoration(labelText: 'Producent'),
                      enabled: canEdit,
                    ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                      enabled: canEdit,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      enabled: canEdit,
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoryCtrl.text.isNotEmpty
                                ? _categoryCtrl.text
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Kategoria',
                            ),
                            items: _categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(
                                      cat[0].toUpperCase() + cat.substring(1),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: canEdit
                                ? (v) => setState(() => _categoryCtrl.text = v!)
                                : null,
                            validator: (v) =>
                                v == null ? 'Wybierz kategoria' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Nowa kategoria',
                          onPressed: canEdit ? _addCategory : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kod kreskowy',
                      ),
                      enabled: canEdit,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      enabled: canEdit,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Wpisz ilość' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Jm.'),
                      items: ['szt', 'm', 'kg', 'kpl']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: canEdit
                          ? (v) => setState(() => _unit = v!)
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(labelText: 'Magazyn'),
                      enabled: canEdit,
                    ),
                    const SizedBox(height: 12),

                    if (_uploading)
                      const Center(child: CircularProgressIndicator()),
                    if (_imageUrl != null)
                      Image.network(_imageUrl!, height: 150),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Zapisz fotka'),
                      onPressed: canEdit ? _changePhoto : null,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: canEdit ? _saveChanges : null,
                      child: const Text('Zapisz'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
