// lib/screens/widgets/stock_item_form.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import '../../repositories/value_lists_repo.dart';
import '../../widgets/autocomplete_text_field.dart';
import '../../widgets/barcode_suffix_icon.dart';
import '../../utils/search_utils.dart';

class StockItemForm extends StatefulWidget {
  const StockItemForm({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final StockItemInitial initial;
  final Future<void> Function(StockItemValues) onSubmit;

  @override
  State<StockItemForm> createState() => _StockItemFormState();
}

class StockItemInitial {
  final String name, sku, barcode, producent, category, location, unit;
  final int quantity;
  final String? imageUrl;
  StockItemInitial({
    this.name = '',
    this.sku = '',
    this.barcode = '',
    this.producent = '',
    this.category = '',
    this.location = '',
    this.unit = 'szt',
    this.quantity = 0,
    this.imageUrl,
  });
}

class StockItemValues {
  String name, sku, barcode, producent, category, location, unit;
  int quantity;
  File? imageFile;
  StockItemValues({
    required this.name,
    required this.sku,
    required this.barcode,
    required this.producent,
    required this.category,
    required this.location,
    required this.unit,
    required this.quantity,
    this.imageFile,
  });
}

class _StockItemFormState extends State<StockItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _producerCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _unit = 'szt';

  final _repo = ValueListsRepo();
  List<String> _categories = [], _producers = [], _models = [];
  File? _pickedImage;
  final _picker = ImagePicker();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl.text = i.name;
    _skuCtrl.text = i.sku;
    _barcodeCtrl.text = i.barcode;
    _producerCtrl.text = i.producent;
    _categoryCtrl.text = i.category;
    _quantityCtrl.text = i.quantity.toString();
    _locationCtrl.text = i.location;
    _unit = i.unit;

    _repo.categories.listen((v) => setState(() => _categories = v));
    _repo.producers.listen((v) => setState(() => _producers = v));
    _repo.models.listen((v) => setState(() => _models = v));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _producerCtrl.dispose();
    _categoryCtrl.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        StockItemValues(
          name: _nameCtrl.text.trim(),
          sku: _skuCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          producent: _producerCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          unit: _unit,
          quantity: int.parse(_quantityCtrl.text.trim()),
          imageFile: _pickedImage,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) return const Center(child: CircularProgressIndicator());

    return DismissKeyboard(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (widget.initial.imageUrl != null
                                  ? NetworkImage(widget.initial.imageUrl!)
                                  : null)
                              as ImageProvider<Object>?,
                    child:
                        _pickedImage == null && widget.initial.imageUrl == null
                        ? const Icon(Icons.camera_alt, size: 48)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),

              AutocompleteTextField(
                label: 'Kategoria',
                controller: _categoryCtrl,
                options: _categories,
                normalize: normalize,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wybierz' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AutocompleteTextField(
                label: 'Producent',
                controller: _producerCtrl,
                options: _producers,
                normalize: normalize,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AutocompleteTextField(
                label: 'Model',
                controller: _nameCtrl,
                options: _models,
                normalize: normalize,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeCtrl,
                decoration: InputDecoration(
                  labelText: 'Kod kreskowy',
                  suffixIcon: BarcodeSuffixIcon(
                    onCode: (code) => setState(() => _barcodeCtrl.text = code),
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(labelText: 'Ilość'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Wpisz liczba' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(
                  labelText: 'Jednostka miary.',
                ),
                items: ['szt', 'm', 'kg', 'kpl']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Magazyn'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text(
                  'Zapisz produkt',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
