// lib/screens/edit_item_screen.dart

import 'dart:io';
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
  late TextEditingController _nameCtrl, _skuCtrl, _categoryCtrl;
  late TextEditingController _barcodeCtrl, _quantityCtrl, _locationCtrl;

  String? _imageUrl;
  String _unit = 'szt';
  bool _saving = false, _uploading = false;
  String? _error;

  final _picker = ImagePicker();
  final _storage = FirebaseStorage.instance.ref();

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: d['name']);
    _skuCtrl = TextEditingController(text: d['sku']);
    _categoryCtrl = TextEditingController(text: d['category']);
    _barcodeCtrl = TextEditingController(text: d['barcode']);
    _quantityCtrl = TextEditingController(text: '${d['quantity']}');
    _unit = d['unit'] ?? 'szt';
    _locationCtrl = TextEditingController(text: d['location']);
    _imageUrl = d['imageUrl'];
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

  Future<void> _changePhoto() async {
    final x = await _picker.pickImage(source: ImageSource.camera);
    if (x == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file = File(x.path);
      final ref = _storage.child('stock_images/${widget.docId}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // update Firestore
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
      appBar: AppBar(title: Text('Edit Item')),
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
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _skuCtrl,
                      decoration: InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: InputDecoration(labelText: 'Category'),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(labelText: 'Barcode'),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Enter a number' : null,
                    ),
                    SizedBox(height: 12),

                    // Unit dropdown
                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: InputDecoration(labelText: 'Unit'),
                      items: [
                        DropdownMenuItem(
                          value: 'szt',
                          child: Text('szt (pcs)'),
                        ),
                        DropdownMenuItem(value: 'm', child: Text('m (meters)')),
                        DropdownMenuItem(
                          value: 'kg',
                          child: Text('kg (kilograms)'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                    SizedBox(height: 12),

                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(labelText: 'Location'),
                    ),
                    SizedBox(height: 12),

                    // Photo preview
                    if (_uploading) Center(child: CircularProgressIndicator()),
                    if (_imageUrl != null)
                      Image.network(_imageUrl!, height: 150),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Change Photo'),
                      onPressed: _changePhoto,
                    ),

                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text('Save Changes'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
