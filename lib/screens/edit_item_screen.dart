// lib/screens/edit_item_screen.dart
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

class EditItemScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const EditItemScreen(
    this.docId, {
    super.key,
    required this.data,
    this.isAdmin = false,
  });

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _producerCtrl,
      _nameCtrl,
      _skuCtrl,
      _categoryCtrl,
      _barcodeCtrl,
      _quantityCtrl,
      _locationCtrl;

  String _unit = 'szt';
  String? _imageUrl;
  File? _pickedImage;

  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();
  final StorageService _storageService = StorageService();

  late final StreamSubscription<QuerySnapshot> _catSub;
  late final StreamSubscription<QuerySnapshot> _prodSub;

  List<String> _categories = [];
  List<String> _producers = [];

  @override
  void initState() {
    super.initState();
    final d = widget.data;

    _producerCtrl = TextEditingController(
      text: d['producent'] as String? ?? '',
    );
    _nameCtrl = TextEditingController(text: d['name'] as String? ?? '');
    _skuCtrl = TextEditingController(text: d['sku'] as String? ?? '');
    _categoryCtrl = TextEditingController(text: d['category'] as String? ?? '');
    _barcodeCtrl = TextEditingController(text: d['barcode'] as String? ?? '');
    _quantityCtrl = TextEditingController(text: '${d['quantity'] ?? 0}');
    _unit = d['unit'] as String? ?? 'szt';
    _locationCtrl = TextEditingController(text: d['location'] as String? ?? '');
    _imageUrl = d['imageUrl'] as String?;

    _catSub = FirebaseFirestore.instance
        .collection('categories')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          setState(() {
            _categories = snap.docs
                .map((doc) => doc['name'] as String)
                .toList();
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
    _prodSub.cancel();

    _producerCtrl.dispose();
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _categoryCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _locationCtrl.dispose();
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final name = _nameCtrl.text.trim();
      final sku = _skuCtrl.text.trim();
      final producent = _producerCtrl.text.trim();
      final barcode = _barcodeCtrl.text.trim();
      final category = _categoryCtrl.text.trim();
      final location = _locationCtrl.text.trim();
      final quantity = int.parse(_quantityCtrl.text.trim());

      final docRef = FirebaseFirestore.instance
          .collection('stock_items')
          .doc(widget.docId);

      await docRef.update({
        'producent': producent,
        'producentFold': normalize(producent),
        'name': name,
        'nameFold': normalize(name),
        'sku': sku,
        'skuFold': normalize(sku),
        'barcode': barcode,
        'category': category,
        'quantity': quantity,
        'unit': _unit,
        'location': location,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      await _ensureCategoryExists(category);
      if (mounted && category.isNotEmpty && !_categories.contains(category)) {
        setState(() => _categories.add(category));
      }
      if (mounted && producent.isNotEmpty && !_producers.contains(producent)) {
        setState(() => _producers.add(producent));
      }

      if (_pickedImage != null) {
        final url = await _storageService.uploadStockFile(
          widget.docId,
          _pickedImage!,
        );
        await docRef.update({'imageUrl': url});
        if (mounted) setState(() => _imageUrl = url);
      }

      if (mounted) _goToInventory();
    } catch (e) {
      setState(() {
        _error = 'Save failed: $e';
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
    final title = 'Edytuj produkt';

    return AppScaffold(
      centreTitle: true,
      title: title,
      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8))],
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

                    // CATEGORY (Autocomplete)
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
                            onSelected: (sel) => _categoryCtrl.text = sel,
                            fieldViewBuilder:
                                (ctx, textCtrl, focusNode, onSubmit) {
                                  textCtrl.text = _categoryCtrl.text;
                                  textCtrl
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(offset: textCtrl.text.length),
                                  );
                                  textCtrl.addListener(
                                    () => _categoryCtrl.text = textCtrl.text,
                                  );

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

                    const SizedBox(height: 12),

                    // PRODUCER (Autocomplete)
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
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _skuCtrl,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),

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

                    // important QTY
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
                        if (!_saving) _saveChanges();
                      },
                    ),

                    const SizedBox(height: 12),

                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 150)
                    else if (_imageUrl != null)
                      Image.network(_imageUrl!, height: 150),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Dodaj zdjęcia produktu'),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.green),
                      label: const Text(
                        'Zaktualizuj produkt',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _saveChanges,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
