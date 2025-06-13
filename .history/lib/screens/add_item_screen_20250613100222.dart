import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddItemScreen extends StatefulWidget {
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _sku = '';
  String _category = '';
  String _barcode = '';
  int _quantity = 0;
  String _location = '';

  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('stock_items').add({
        'name': _name,
        'sku': _sku,
        'category': _category,
        'barcode': _barcode,
        'quantity': _quantity,
        'location': _location,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Navigator.of(context).pop(); // back to list
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
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (v) => _name = v!.trim(),
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (v) => _sku = v!.trim(),
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Category'),
                      onSaved: (v) => _category = v!.trim(),
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Barcode'),
                      onSaved: (v) => _barcode = v!.trim(),
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      initialValue: '0',
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Enter a number' : null,
                      onSaved: (v) => _quantity = int.parse(v!),
                    ),
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Location'),
                      onSaved: (v) => _location = v!.trim(),
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
