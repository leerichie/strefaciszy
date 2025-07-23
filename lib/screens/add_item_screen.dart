// lib/screens/add_item_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import '../services/storage_service.dart';

class AddItemScreen extends StatefulWidget {
  final String? initialBarcode;
  final String? initialName;
  const AddItemScreen({super.key, this.initialBarcode, this.initialName});

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
  late final TextEditingController _categoryCtrl;

  String _unit = 'szt';
  String? _selectedCategory;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  late final StreamSubscription<QuerySnapshot> _catSub;
  List<String> _categories = [];

  late final StreamSubscription<QuerySnapshot> _prodSub;
  List<String> _producers = [];

  @override
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.initialBarcode ?? '');
    _nameCtrl.text = widget.initialName ?? '';
    _producerCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();
    _catSub = FirebaseFirestore.instance
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _categories = snap.docs.map((d) => d['name'] as String).toList();
          });
        });
    _prodSub = FirebaseFirestore.instance
        .collection('stock_items')
        .snapshots()
        .listen((snap) {
          final set = <String>{};
          for (final d in snap.docs) {
            final p = (d['producent'] ?? '').toString().trim();
            if (p.isNotEmpty) set.add(p);
          }
          setState(() {
            _producers = set.toList()..sort();
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
    _categoryCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
    _prodSub.cancel();
    super.dispose();
  }

  void _goToInventory() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => InventoryListScreen(isAdmin: true)),
      (route) => route.isFirst,
    );
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

  Future<void> _ensureCategoryExists(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_categories.contains(trimmed)) return;

    final q = await FirebaseFirestore.instance
        .collection('categories')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('categories').add({
        'name': trimmed,
      });
    }
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

      final name = _nameCtrl.text.trim();
      final sku = _skuCtrl.text.trim();
      final barcode = _barcodeCtrl.text.trim();
      final producent = _producerCtrl.text.trim();
      final category = _categoryCtrl.text.trim();

      final docRef = await col.add({
        'name': name,
        'nameFold': normalize(name),
        'sku': sku,
        'skuFold': normalize(sku),
        'category': category,
        'barcode': barcode,
        'producent': producent,
        'producentFold': normalize(producent),
        'quantity': int.parse(_quantityCtrl.text.trim()),
        'unit': _unit,
        'location': _locationCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      if (mounted && producent.isNotEmpty && !_producers.contains(producent)) {
        setState(() => _producers.add(producent));
      }

      await _ensureCategoryExists(category);

      if (mounted && category.isNotEmpty && !_categories.contains(category)) {
        setState(() => _categories.add(category));
      }

      if (_pickedImage != null) {
        final url = await _storageService.uploadStockFile(
          docRef.id,
          _pickedImage!,
        );
        await docRef.update({'imageUrl': url});
      }

      _goToInventory();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen(returnCode: true)),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _barcodeCtrl.text = code);
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
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (TextEditingValue tev) {
                              if (tev.text.isEmpty) return _categories;
                              final q = normalize(tev.text);
                              return _categories.where(
                                (c) => normalize(c).contains(q),
                              );
                            },
                            initialValue: TextEditingValue(
                              text: _categoryCtrl.text,
                            ),
                            onSelected: (sel) {
                              _categoryCtrl.text = sel;
                              _selectedCategory = sel;
                            },
                            fieldViewBuilder:
                                (ctx, textCtrl, focusNode, onSubmit) {
                                  textCtrl.text = _categoryCtrl.text;
                                  textCtrl
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(offset: textCtrl.text.length),
                                  );
                                  textCtrl.addListener(() {
                                    _categoryCtrl.text = textCtrl.text;
                                    _selectedCategory = textCtrl.text;
                                  });

                                  return TextFormField(
                                    controller: textCtrl,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Kategoria',
                                      suffixIcon: PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.arrow_drop_down_circle_outlined,
                                        ),
                                        onSelected: (val) {
                                          _categoryCtrl.text = val;
                                          textCtrl.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: val.length,
                                                ),
                                              );
                                        },
                                        itemBuilder: (_) => _categories
                                            .map(
                                              (c) => PopupMenuItem<String>(
                                                value: c,
                                                child: Text(c),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Wybierz'
                                        : null,
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
                                  );
                                },
                          ),
                        ),
                      ],
                    ),

                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            optionsBuilder: (TextEditingValue tev) {
                              if (tev.text.isEmpty) return _producers;
                              final q = normalize(tev.text);
                              return _producers.where(
                                (p) => normalize(p).contains(q),
                              );
                            },
                            initialValue: TextEditingValue(
                              text: _producerCtrl.text,
                            ),
                            onSelected: (sel) => _producerCtrl.text = sel,
                            fieldViewBuilder:
                                (ctx, textCtrl, focusNode, onSubmit) {
                                  textCtrl.text = _producerCtrl.text;
                                  textCtrl
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(offset: textCtrl.text.length),
                                  );
                                  textCtrl.addListener(
                                    () => _producerCtrl.text = textCtrl.text,
                                  );

                                  return TextFormField(
                                    controller: textCtrl,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Producent',
                                      suffixIcon: PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.arrow_drop_down_circle_outlined,
                                        ),
                                        onSelected: (val) {
                                          _producerCtrl.text = val;
                                          textCtrl.selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: val.length,
                                                ),
                                              );
                                        },
                                        itemBuilder: (_) => _producers
                                            .map(
                                              (p) => PopupMenuItem<String>(
                                                value: p,
                                                child: Text(p),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    onFieldSubmitted: (_) =>
                                        FocusScope.of(context).nextFocus(),
                                  );
                                },
                          ),
                        ),
                      ],
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

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kod Kreskowy',
                        suffixIcon: IconButton(
                          tooltip: 'Skanuj kod',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),

                    const SizedBox(height: 12),

                    // TextFormField(
                    //   controller: _quantityCtrl,
                    //   decoration: const InputDecoration(labelText: 'Ilość'),
                    //   keyboardType: TextInputType.number,
                    //   validator: (v) =>
                    //       int.tryParse(v!) == null ? 'Wpisz liczba' : null,
                    //   textInputAction: TextInputAction.next,
                    //   onFieldSubmitted: (_) =>
                    //       FocusScope.of(context).nextFocus(),
                    // ),
                    // const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Jednostka miary.',
                      ),
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
                      label: const Text('Dodaj zdjęcia produktu'),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.green),
                      label: const Text(
                        'Zapisz produkt',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
