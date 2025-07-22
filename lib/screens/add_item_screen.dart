// lib/screens/add_item_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import '../services/storage_service.dart';
import 'package:strefa_ciszy/widgets/app_drawer.dart';

class AddItemScreen extends StatefulWidget {
  final String? initialBarcode;
  const AddItemScreen({super.key, this.initialBarcode});

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  late final TextEditingController _barcodeCtrl;
  final _quantityCtrl = TextEditingController(text: '0');
  final _locationCtrl = TextEditingController();
  late final TextEditingController _producerCtrl;
  String _unit = 'szt';
  String? _selectedCategory;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  late final StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');
    _producerCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _producerCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (x != null) setState(() => _pickedImage = File(x.path));
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
    final title = 'Dodaj';
    return AppScaffold(
      centreTitle: true,
      title: title,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
              ],
            ),
        ),
      ),
      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

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
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Model'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Kategoria',
                            ),
                            value: _selectedCategory,
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
                            onChanged: (cat) =>
                                setState(() => _selectedCategory = cat),
                            validator: (cat) => cat == null ? 'Wybierz' : null,
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
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kod Kreskowy',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Wpisz liczba' : null,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
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
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(labelText: 'Magazyn'),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_saving) _save();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 150),
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
