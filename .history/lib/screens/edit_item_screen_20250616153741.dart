// lib/screens/edit_item_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
      _barcodeCtrl,
      _quantityCtrl,
      _locationCtrl;
  String _unit = 'szt';
  String? _selectedCategory;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final ImagePicker _picker = ImagePicker();
  late StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    // init controllers from data
    _nameCtrl = TextEditingController(text: widget.data['name'] ?? '');
    _skuCtrl = TextEditingController(text: widget.data['sku'] ?? '');
    _barcodeCtrl = TextEditingController(text: widget.data['barcode'] ?? '');
    _quantityCtrl = TextEditingController(
      text: (widget.data['quantity'] ?? '').toString(),
    );
    _locationCtrl = TextEditingController(text: widget.data['location'] ?? '');
    _unit = widget.data['unit'] as String? ?? 'szt';
    _selectedCategory = widget.data['category'] as String?;
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

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x != null) setState(() => _pickedImage = File(x.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('stock_items')
          .doc(widget.docId);

      // update fields
      await ref.update({
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'quantity': int.parse(_quantityCtrl.text.trim()),
        'unit': _unit,
        'location': _locationCtrl.text.trim(),
        'category': _selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      // handle photo
      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance.ref(
          'stock_images/${widget.docId}.jpg',
        );
        await storageRef.putFile(_pickedImage!);
        final url = await storageRef.getDownloadURL();
        await ref.update({'imageUrl': url});
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
                      controller: _skuCtrl,
                      decoration: InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),

                    // ←– Category dropdown + add button
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
                      decoration: InputDecoration(labelText: 'Kod kreskowy'),
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
                      items: ['szt', 'm', 'kg']
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
                      label: Text('Zmień zdjęcie'),
                      onPressed: _pickImage,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text('Zapisz zmiany'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
