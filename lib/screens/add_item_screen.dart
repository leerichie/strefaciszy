// lib/screens/add_item_screen.dart

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

  // Controllers
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  late TextEditingController _barcodeCtrl;
  final _quantityCtrl = TextEditingController(text: '0');
  final _locationCtrl = TextEditingController();

  // Fields
  String _unit = 'szt';

  // State
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance.ref();

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
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
      final col = FirebaseFirestore.instance.collection('stock_items');

      final docRef = await col.add({
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
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
                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),

                    // SKU
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),

                    // Category
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: InputDecoration(labelText: 'Category'),
                    ),
                    SizedBox(height: 12),

                    // Barcode
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(labelText: 'Barcode'),
                    ),
                    SizedBox(height: 12),

                    // Quantity
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Enter a number' : null,
                    ),
                    SizedBox(height: 12),

                    // Unit selector
                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: InputDecoration(labelText: 'Unit'),
                      items: [
                        DropdownMenuItem(value: 'szt', child: Text('szt')),
                        DropdownMenuItem(value: 'm', child: Text('m')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        // add more units if needed
                      ],
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    SizedBox(height: 12),

                    // Location
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(labelText: 'Location'),
                    ),
                    SizedBox(height: 12),

                    // Photo preview & picker
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 150),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Pick Photo'),
                      onPressed: _pickImage,
                    ),
                    SizedBox(height: 24),

                    // Save button
                    ElevatedButton(
                      onPressed: _save,
                      child: Text('Create Item'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
