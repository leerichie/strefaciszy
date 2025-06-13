// lib/screens/add_item_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final _categoryCtrl = TextEditingController();
  late TextEditingController _barcodeCtrl;
  final _quantityCtrl = TextEditingController(text: '0');
  final _locationCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefill barcode if passed in
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      // Grab the current user for audit fields
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Add the new item
      await FirebaseFirestore.instance.collection('stock_items').add({
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'quantity': int.parse(_quantityCtrl.text.trim()),
        'location': _locationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        // itemIndex will be set by your onCreate Cloud Function
      });

      Navigator.of(context).pop(); // back to inventory list
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
      appBar: AppBar(title: Text('Add Inventory Item')),
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
                      validator: (v) => int.tryParse(v!.trim()) == null
                          ? 'Enter a number'
                          : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(labelText: 'Location'),
                    ),
                    SizedBox(height: 24),
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
