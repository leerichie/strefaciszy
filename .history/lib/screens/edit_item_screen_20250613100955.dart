// lib/screens/edit_item_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditItemScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditItemScreen(this.docId, {super.key, required this.data});

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _locationCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: d['name']);
    _skuCtrl = TextEditingController(text: d['sku']);
    _categoryCtrl = TextEditingController(text: d['category']);
    _barcodeCtrl = TextEditingController(text: d['barcode']);
    _quantityCtrl = TextEditingController(text: '${d['quantity']}');
    _locationCtrl = TextEditingController(text: d['location']);
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

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
            'location': _locationCtrl.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': uid,
          });
      Navigator.of(context).pop(); // back to detail
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
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(labelText: 'Location'),
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
