// lib/screens/add_item_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

class AddItemScreen extends StatefulWidget {
  final String? initialBarcode;

  const AddItemScreen({super.key, this.initialBarcode});

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}
x
class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _producerCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  late final TextEditingController _barcodeCtrl;
  final _quantityCtrl = TextEditingController(text: '0');
  final _locationCtrl = TextEditingController();

  String _unit = 'szt';
  String? _selectedCategory;
  List<String> _categories = [];

  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  final _storageService = StorageService();

  late final StreamSubscription<QuerySnapshot> _catSub;

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');
    _catSub = FirebaseFirestore.instance
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _categories = snap.docs.map((d) => d['name'] as String).toList();
          });
        });
  }

  @override
  void dispose() {
    _catSub.cancel();
    _producerCtrl.dispose();
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Zrób fota'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Wybierz z galerii'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    }
  }

  Future<void> _addCategory() async {
    String? newName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa Kategoria'),
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
                setState(() => _selectedCategory = newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final col = FirebaseFirestore.instance.collection('stock_items');
      final docRef = await col.add({
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'category': _selectedCategory,
        'barcode': _barcodeCtrl.text.trim(),
        'producent': _producerCtrl.text.trim(),
        'quantity': int.parse(_quantityCtrl.text.trim()),
        'unit': _unit,
        'location': _locationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      if (_pickedImage != null) {
        final url = await _storageService.uploadStockFile(
          docRef.id,
          _pickedImage!,
          overwrite: false, 
        );
        await docRef.update({'imageUrl': url});
      }

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj towar')),
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

                    // Producer
                    TextFormField(
                      controller: _producerCtrl,
                      decoration: const InputDecoration(labelText: 'Producent'),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                      validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                    ),
                    const SizedBox(height: 12),

                    // SKU
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Wymagane' : null,
                    ),
                    const SizedBox(height: 12),

                    // Category + Add
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Kategoria',
                            ),
                            value: _selectedCategory,
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat[0].toUpperCase() + cat.substring(1),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v),
                            validator: (v) =>
                                v == null ? 'Wybierz kategorię' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Nowa kategoria',
                          onPressed: _addCategory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Barcode
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kod kreskowy',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quantity
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Wpisz liczbę' : null,
                    ),
                    const SizedBox(height: 12),

                    // Unit
                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Jm.'),
                      items: ['szt', 'm', 'kg', 'kpl']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    const SizedBox(height: 12),

                    // Location
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(labelText: 'Magazyn'),
                    ),
                    const SizedBox(height: 12),

                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 150),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Dodaj Fotka'),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Zapisz produkt'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
