import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class AddContactScreen extends StatefulWidget {
  final bool isAdmin;
  final String? contactId;
  const AddContactScreen({Key? key, this.isAdmin = false, this.contactId})
    : super(key: key);

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  bool _submitting = false;
  Uint8List? _imageData;
  String? _existingPhotoUrl;
  final _picker = ImagePicker();
  String? _selectedCustomerId;

  List<String> _extraNumbers = [];
  List<String> _categories = [];
  String? _category;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _customerDocs = [];
  List<String> _customerNames = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.contactId != null) {
      _loadContact();
    }
    _loadCustomerSuggestions();
  }

  Future<void> _loadCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('metadata')
        .doc('contactTypes')
        .get();
    setState(() {
      _categories = List<String>.from((snap.data()!['types'] as List));
    });
  }

  Future<void> _loadCustomerSuggestions() async {
    final custSnap = await FirebaseFirestore.instance
        .collection('customers')
        .orderBy('name')
        .get();

    final contactSnap = await FirebaseFirestore.instance
        .collection('contacts')
        .get();
    final existing = contactSnap.docs.map((d) => d.id).toSet();

    final filtered = custSnap.docs
        .where((d) => !existing.contains(d.id))
        .toList();

    setState(() {
      _customerDocs = filtered;
      _customerNames = filtered
          .map((d) => (d.data()! as Map<String, dynamic>)['name'] as String)
          .toList();
    });
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageData = bytes;
        _existingPhotoUrl = null;
      });
    }
  }

  Future<void> _loadContact() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('contacts')
        .doc(widget.contactId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameCtrl.text = data['name'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _extraNumbers = List<String>.from(data['extraNumbers'] ?? []);
      _emailCtrl.text = data['email'] ?? '';
      _addressCtrl.text = data['address'] ?? '';
      _websiteCtrl.text = data['www'] ?? '';
      _noteCtrl.text = data['note'] ?? '';
      _category = data['contactType'];
      _existingPhotoUrl = data['photoUrl'];
    }
    setState(() => _loading = false);
  }

  Future<String?> _uploadPhoto(String id) async {
    if (_imageData == null) return null;
    final ref = FirebaseStorage.instance.ref('contacts/$id/photo.jpg');
    await ref.putData(_imageData!);
    return await ref.getDownloadURL();
  }

  Future<void> _addExtraNumber() async {
    String temp = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj numer'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Numer telefonu'),
          keyboardType: TextInputType.phone,
          onChanged: (v) => temp = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (temp.isNotEmpty) {
                setState(() => _extraNumbers.add(temp));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    String temp = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj typ kontaktu'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Typ'),
          onChanged: (v) => temp = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (temp.isNotEmpty) {
                setState(() {
                  _categories.add(temp);
                  _category = temp;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
    if (temp.isEmpty) return;
    setState(() {
      _categories.add(temp);
      _category = temp;
    });
    final ref = FirebaseFirestore.instance
        .collection('metadata')
        .doc('contactTypes');
    await ref.update({
      'types': FieldValue.arrayUnion([temp]),
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final col = FirebaseFirestore.instance.collection('contacts');
    final data = {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'extraNumbers': _extraNumbers,
      'email': _emailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'www': _websiteCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
      'contactType': _category,
      'updatedAt': FieldValue.serverTimestamp(),
      if (_selectedCustomerId != null) 'linkedCustomerId': _selectedCustomerId,
    };
    try {
      if (widget.contactId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await col.add(data);
        final url = await _uploadPhoto(docRef.id);
        if (url != null) await docRef.update({'photoUrl': url});
      } else {
        await col.doc(widget.contactId!).update(data);
        final url = await _uploadPhoto(widget.contactId!);
        if (url != null)
          await col.doc(widget.contactId!).update({'photoUrl': url});
      }
      Navigator.pop(context);
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd przy zapisie: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.contactId == null ? 'Dodaj Kontakt' : 'Edytuj Kontakt',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const CustomerListScreen(isAdmin: true),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: _imageData != null
                              ? MemoryImage(_imageData!)
                              : (_existingPhotoUrl != null
                                        ? NetworkImage(_existingPhotoUrl!)
                                        : null)
                                    as ImageProvider?,
                          child: _imageData == null && _existingPhotoUrl == null
                              ? const Icon(Icons.camera_alt, size: 48)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _category,
                              decoration: const InputDecoration(
                                labelText: 'Typ kontaktu',
                              ),
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Wybierz...' : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Dodaj typ',
                            onPressed: _addCategory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (widget.contactId == null) ...[
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue txt) {
                            if (txt.text.isEmpty) return const [];
                            return _customerNames.where(
                              (name) => name.toLowerCase().contains(
                                txt.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (selection) {
                            _nameCtrl.text = selection;

                            final doc = _customerDocs.firstWhere(
                              (d) => (d.data())['name'] == selection,
                            );
                            _selectedCustomerId = doc.id;
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                controller.text = _nameCtrl.text;
                                controller
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length),
                                );
                                controller.addListener(
                                  () => _nameCtrl.text = controller.text,
                                );

                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Nazwa',
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Wpisz nazwę'
                                      : null,
                                );
                              },
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nazwa'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Wpisz nazwę'
                              : null,
                        ),
                      ],

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Telefon',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Wpisz numer'
                                  : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Dodaj numer',
                            onPressed: _addExtraNumber,
                          ),
                        ],
                      ),
                      ..._extraNumbers.map(
                        (num) => ListTile(
                          title: Text(num),
                          onTap: () {
                            setState(() {
                              _phoneCtrl.text = num;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Adres'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _websiteCtrl,
                        decoration: const InputDecoration(labelText: 'WWW'),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notatka',
                          alignLabelWithHint: true,
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: widget.contactId == null
            ? 'Zapisz Kontakt'
            : 'Aktualizuj Kontakt',
        onPressed: _submitting ? null : _save,
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.people),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerListScreen(isAdmin: widget.isAdmin),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Skanuj',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
