// lib/screens/add_item_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
  late TextEditingController _barcodeCtrl;
  final _quantityCtrl = TextEditingController(text: '0');
  final _locationCtrl = TextEditingController();
  String _unit = 'szt';
  String? _selectedCategory;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  late StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');
    // subscribe to categories
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
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x != null) setState(() => _pickedImage = File(x.path));
  }

  Future<void> _addCategory() async {
    String? newName;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nowa Kategoria'),
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
                setState(() => _selectedCategory = newName);
              }
              Navigator.pop(ctx);
            },
            child: Text('Dodaj'),
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
        'quantity': int.parse(_quantityCtrl.text.trim()),
        'unit': _unit,
        'location': _locationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      if (_pickedImage != null) {
        final path = 'stock_images/${docRef.id}.jpg';
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putFile(_pickedImage!);
        final url = await ref.getDownloadURL();
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
      appBar: AppBar(title: Text('Dodaj towar')),
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
                            value: _selectedCategory,
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat[0].toUpperCase() + cat.substring(1),
                                ),
                              );
                            }).toList(),
                            onChanged: (cat) =>
                                setState(() => _selectedCategory = cat),
                            validator: (cat) => cat == null ? 'Wybierz' : null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          tooltip: 'Nowa kategoria',
                          onPressed: _addCategory,
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(labelText: 'Kod Kreskowy'),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Wpisz cyfrę' : null,
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
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 150),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Dodaj Fotkę'),
                      onPressed: _pickImage,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text('Zapisz produkt'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
