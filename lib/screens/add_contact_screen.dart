// lib/screens/add_contact_screen.dart
import 'dart:async'; // NEW
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // NEW (for dates)
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'project_editor_screen.dart'; // NEW (open after add?)

class AddContactScreen extends StatefulWidget {
  final bool isAdmin;
  final String? contactId;
  final String? linkedCustomerId;
  const AddContactScreen({
    super.key,
    this.isAdmin = false,
    this.contactId,
    this.linkedCustomerId,
  });

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

  // --- NEW: Project fields --------------------------------------------------
  bool _createProjectNow =
      false; // if you ever want auto project from here (kept for future)
  final _projTitleCtrl = TextEditingController();
  DateTime? _projStartDate;
  DateTime? _projEndDate;
  final _projCostCtrl = TextEditingController();
  // -------------------------------------------------------------------------

  bool _loading = false;
  bool _submitting = false;
  Uint8List? _imageData;
  String? _existingPhotoUrl;
  final _picker = ImagePicker();
  String? _selectedCustomerId;

  // NEW: we keep local created ids
  String? _contactId; // will hold (existing or newly created) contact id
  String? _customerId; // if/when we create the customer doc
  bool _createdEmptyDraft =
      false; // if we created a draft to autosave, delete on exit if still empty

  // NEW: debounce timer for autosave
  Timer? _debounce;

  List<String> _extraNumbers = [];
  List<String> _categories = [];
  String? _category;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _customerDocs = [];
  List<String> _customerNames = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    _selectedCustomerId = widget.linkedCustomerId;

    if (widget.contactId != null) {
      _contactId = widget.contactId;
      _loadContact();
    }
    if (widget.linkedCustomerId != null) {
      _selectedCustomerId = widget.linkedCustomerId;
      _customerId = widget.linkedCustomerId; // might already be a customer id
    }
    _loadCustomerSuggestions();

    // Attach listeners for autosave
    _attachAutoSaveListeners();
  }

  void _attachAutoSaveListeners() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _websiteCtrl,
      _noteCtrl,
    ]) {
      c.addListener(_scheduleAutoSave);
    }
  }

  void _scheduleAutoSave() {
    if (_submitting) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!_formKey.currentState!.validate()) {
      // still allow partial save? For now, only save when valid category & name
      // but we can skip validation here to avoid blocking.
    }

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
    };

    final cid = widget.linkedCustomerId ?? _selectedCustomerId ?? _customerId;
    if (cid != null) data['linkedCustomerId'] = cid;

    final col = FirebaseFirestore.instance.collection('contacts');

    try {
      if (_contactId == null) {
        // create draft
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await col.add(data);
        _contactId = docRef.id;
        _createdEmptyDraft = true;
      } else {
        await col.doc(_contactId!).set(data, SetOptions(merge: true));
      }
    } catch (e) {
      // ignore silent fail or show snackbar
    }
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
          .map((d) => (d.data())['name'] as String)
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
      // autosave photo
      _scheduleAutoSave();
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
      _customerId = data['linkedCustomerId'] as String?;
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
                _scheduleAutoSave();
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
    final ref = FirebaseFirestore.instance
        .collection('metadata')
        .doc('contactTypes');
    await ref.update({
      'types': FieldValue.arrayUnion([temp]),
    });
    _scheduleAutoSave();
  }

  /// Called when user presses FAB to create a project
  Future<void> _addProject() async {
    // Ensure we have a customerId. If not, create one now.
    await _ensureCustomerExists();

    if (_customerId == null) return;

    String title = '';
    DateTime? startDate;
    DateTime? estimatedEndDate;
    String costStr = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nowy Projekt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nazwa projektu',
                  ),
                  onChanged: (v) => title = v.trim(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Start'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(startDate!),
                      ),
                    ),
                    TextButton(
                      child: const Text('Wybierz'),
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => startDate = dt);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimatedEndDate == null
                            ? 'Oczek. Koniec'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(estimatedEndDate!),
                      ),
                    ),
                    TextButton(
                      child: const Text('Wybierz'),
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: estimatedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => estimatedEndDate = dt);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Oszac. koszt'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => costStr = v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isEmpty) return;

                final data = <String, dynamic>{
                  'title': title,
                  'status': 'draft',
                  'contactId': _contactId,
                  'customerId': _customerId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser!.uid,
                  'items': <Map<String, dynamic>>[],
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (estimatedEndDate != null)
                    'estimatedEndDate': Timestamp.fromDate(estimatedEndDate!),
                };
                final cost = double.tryParse(costStr.replaceAll(',', '.'));
                if (cost != null) data['estimatedCost'] = cost;

                await FirebaseFirestore.instance
                    .collection('customers')
                    .doc(_customerId)
                    .collection('projects')
                    .add(data);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureCustomerExists() async {
    if (_customerId != null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Najpierw dodaj klienta')));
      return;
    }

    final custRef = await FirebaseFirestore.instance
        .collection('customers')
        .add({
          'name': name,
          'nameFold': name.toLowerCase(),
          'contactId': _contactId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    _customerId = custRef.id;

    // link contact
    if (_contactId != null) {
      await FirebaseFirestore.instance
          .collection('contacts')
          .doc(_contactId)
          .set({'linkedCustomerId': _customerId}, SetOptions(merge: true));
    }
  }

  Future<void> _finalizeImage() async {
    if (_contactId == null) return;
    final url = await _uploadPhoto(_contactId!);
    if (url != null) {
      await FirebaseFirestore.instance
          .collection('contacts')
          .doc(_contactId!)
          .update({'photoUrl': url});
    }
  }

  /// Old save button is gone, but we still might need a final submit (unused now)
  Future<void> _legacySaveAndPop() async {
    _submitting = true;
    await _autoSave(); // ensure last data saved
    await _finalizeImage(); // upload if pending
    if (!mounted) return;

    Navigator.pop(context, {
      'contactId': _contactId,
      'name': _nameCtrl.text.trim(),
      'customerId': _customerId,
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _noteCtrl.dispose();
    _projTitleCtrl.dispose();
    _projCostCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    _debounce?.cancel();
    await _autoSave();
    await _finalizeImage();

    // If we created a blank draft and name is still empty, clean it up
    if (_createdEmptyDraft &&
        (_nameCtrl.text.trim().isEmpty) &&
        _contactId != null) {
      await FirebaseFirestore.instance
          .collection('contacts')
          .doc(_contactId)
          .delete();
      _contactId = null;
    }

    Navigator.pop(context, {
      'contactId': _contactId,
      'name': _nameCtrl.text.trim(),
      'customerId': _customerId,
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contactId == null ? 'Dodaj Klient' : 'Edytuj Klient';

    return WillPopScope(
      onWillPop: _onWillPop, // intercept back to return map
      child: AppScaffold(
        floatingActionButton: FloatingActionButton(
          tooltip: 'Dodaj Projekt',
          onPressed: _addProject,
          child: const Icon(Icons.playlist_add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        title: title,
        centreTitle: true,

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
                            child:
                                _imageData == null && _existingPhotoUrl == null
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
                                onChanged: (v) {
                                  setState(() => _category = v);
                                  _scheduleAutoSave();
                                },
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Wybierz...'
                                    : null,
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
                              _scheduleAutoSave();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  controller.text = _nameCtrl.text;
                                  controller.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: controller.text.length,
                                        ),
                                      );
                                  controller.addListener(() {
                                    _nameCtrl.text = controller.text;
                                    _scheduleAutoSave();
                                  });

                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Imię i Nazwisko',
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
                            decoration: const InputDecoration(
                              labelText: 'Imię i Nazwisko',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wpisz nazwę'
                                : null,
                            onChanged: (_) => _scheduleAutoSave(),
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
                                onChanged: (_) => _scheduleAutoSave(),
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
                              _scheduleAutoSave();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // TextFormField(
                        //   controller: _emailCtrl,
                        //   decoration: const InputDecoration(labelText: 'Email'),
                        //   keyboardType: TextInputType.emailAddress,
                        //   onChanged: (_) => _scheduleAutoSave(),
                        // ),
                        // const SizedBox(height: 12),

                        // TextFormField(
                        //   controller: _addressCtrl,
                        //   decoration: const InputDecoration(labelText: 'Adres'),
                        //   onChanged: (_) => _scheduleAutoSave(),
                        // ),
                        // const SizedBox(height: 12),
                        // TextFormField(
                        //   controller: _websiteCtrl,
                        //   decoration: const InputDecoration(labelText: 'WWW'),
                        //   keyboardType: TextInputType.url,
                        //   onChanged: (_) => _scheduleAutoSave(),
                        // ),
                        // const SizedBox(height: 12),
                        // TextFormField(
                        //   controller: _noteCtrl,
                        //   decoration: const InputDecoration(
                        //     labelText: 'Notatka',
                        //     alignLabelWithHint: true,
                        //   ),
                        //   minLines: 1,
                        //   maxLines: 4,
                        //   onChanged: (_) => _scheduleAutoSave(),
                        // ),
                        // const SizedBox(height: 24),

                        //  PROJECTS
                        if (_customerId != null) ...[
                          const Divider(),
                          Text(
                            'Projekty',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('customers')
                                .doc(_customerId)
                                .collection('projects')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (ctx, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              if (snap.hasError) {
                                return Text('Error: ${snap.error}');
                              }
                              final docs = snap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Text('Brak projektów.');
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final d = docs[i];
                                  final data = d.data();
                                  return ListTile(
                                    title: Text(data['title'] ?? '—'),
                                    subtitle: Text(
                                      DateFormat(
                                        'dd.MM.yyyy • HH:mm',
                                        'pl_PL',
                                      ).format(
                                        (data['createdAt'] as Timestamp)
                                            .toDate()
                                            .toLocal(),
                                      ),
                                    ),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProjectEditorScreen(
                                          customerId: _customerId!,
                                          projectId: d.id,
                                          isAdmin: widget.isAdmin,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 80), // space for FAB
                        ],
                        // ------------------------------------------------------------------
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
