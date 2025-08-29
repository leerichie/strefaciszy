// lib/screens/add_contact_screen.dart
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'project_editor_screen.dart';

class AddContactScreen extends StatefulWidget {
  final bool isAdmin;
  final String? contactId;
  final String? linkedCustomerId;
  final bool forceAsContact;
  const AddContactScreen({
    super.key,
    this.isAdmin = false,
    this.contactId,
    this.linkedCustomerId,
    this.forceAsContact = false,
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

  final bool _createProjectNow = false;
  final _projTitleCtrl = TextEditingController();
  DateTime? _projStartDate;
  DateTime? _projEndDate;
  final _projCostCtrl = TextEditingController();

  bool _loading = false;
  bool _submitting = false;
  Uint8List? _imageData;
  String? _existingPhotoUrl;
  final _picker = ImagePicker();
  String? _selectedCustomerId;

  String? _contactId;
  String? _customerId;
  final bool _createdEmptyDraft = false;

  Timer? _debounce;

  List<String> _extraNumbers = [];
  final List<String> _addedExtraFields = [];
  final _secondPhoneCtrl = TextEditingController();

  List<String> _categories = [];
  String? _category;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _customerDocs = [];
  List<String> _customerNames = [];

  bool _isPrimaryContact = false;
  bool get _isEditing => widget.contactId != null;
  bool get _isNewClient =>
      widget.contactId == null &&
      !_isPrimaryContact &&
      (_category?.toLowerCase() == 'klient');

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allProjects = [];
  bool _projectsLoading = false;
  String? _selectedProjectId;

  List<String> _selectedProjectIds = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _selectedCustomerId = widget.linkedCustomerId;
    if (widget.contactId != null) {
      _contactId = widget.contactId;
      _loadContact().then((_) => _checkIfPrimaryClient());
    }
    if (widget.linkedCustomerId != null) {
      _selectedCustomerId = widget.linkedCustomerId;
      _customerId = widget.linkedCustomerId;
    }
    _loadCustomerSuggestions();
    _attachAutoSaveListeners();

    if (widget.linkedCustomerId == null) {
      _loadAllProjects();
    }
  }

  final List<String> _availableExtraFields = [
    'Drugi numer',
    'Adres',
    'WWW',
    'Notatka',
  ];

  Future<void> _loadAllProjects() async {
    setState(() => _projectsLoading = true);

    final snap = await FirebaseFirestore.instance
        .collectionGroup('projects')
        .orderBy('title')
        .get();
    setState(() {
      _allProjects = snap.docs;
      _projectsLoading = false;
    });
  }

  Future<void> _checkIfPrimaryClient() async {
    if (_customerId == null || widget.contactId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(_customerId)
        .get();
    final data = doc.data();
    if (data != null && data['contactId'] == widget.contactId) {
      setState(() => _isPrimaryContact = true);
    }
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final data = {
      'name': name,
      'phone': _phoneCtrl.text.trim(),
      'extraNumbers': _addedExtraFields.contains('Drugi numer')
          ? <String>[_secondPhoneCtrl.text.trim(), ..._extraNumbers]
          : _extraNumbers,
      'email': _emailCtrl.text.trim(),
      if (_addedExtraFields.contains('Adres'))
        'address': _addressCtrl.text.trim(),
      if (_addedExtraFields.contains('WWW')) 'www': _websiteCtrl.text.trim(),
      if (_addedExtraFields.contains('Notatka')) 'note': _noteCtrl.text.trim(),
      'contactType': (_isPrimaryContact || _isNewClient) ? 'Klient' : _category,
      if (_customerId != null) 'linkedCustomerId': _customerId,
      'updatedAt': FieldValue.serverTimestamp(),
      // if (_selectedProjectId != null) 'linkedProjectId': _selectedProjectId,
      'linkedProjectIds': _selectedProjectIds,

      if (_customerId != null) 'linkedCustomerId': _customerId,
    };

    if (_customerId == null && _selectedProjectIds.isNotEmpty) {
      // find that project in our in‐memory list
      final projId = _selectedProjectIds.first;
      final projDoc = _allProjects.firstWhere((d) => d.id == projId);
      // its parent is customers/{custId}/projects
      _customerId = projDoc.reference.parent.parent!.id;
      data['linkedCustomerId'] = _customerId;
    } else if (_customerId != null) {
      data['linkedCustomerId'] = _customerId;
    }

    data['updatedAt'] = FieldValue.serverTimestamp();
    final contactsCol = FirebaseFirestore.instance.collection('contacts');
    if (_contactId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final docRef = await contactsCol.add(data);
      _contactId = docRef.id;
    } else {
      await contactsCol.doc(_contactId!).set(data, SetOptions(merge: true));
    }

    final isKlient =
        (_isPrimaryContact || _isNewClient) ||
        (_category?.toLowerCase() == 'klient');
    if (isKlient && _customerId == null && _contactId != null) {
      final custRef = await FirebaseFirestore.instance
          .collection('customers')
          .add({
            'name': name,
            'nameFold': name.toLowerCase(),
            'contactId': _contactId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _customerId = custRef.id;

      await contactsCol.doc(_contactId!).update({
        'linkedCustomerId': _customerId,
      });
    }

    if (_customerId != null && _contactId != null) {
      final custDoc = FirebaseFirestore.instance
          .collection('customers')
          .doc(_customerId!);
      final snap = await custDoc.get();
      final custData = snap.data();
      if (custData != null && custData['contactId'] == _contactId) {
        await custDoc.set({
          'name': name,
          'nameFold': name.toLowerCase(),
        }, SetOptions(merge: true));
      }
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
    final ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Zrób zdjęcie'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Wybierz z galerii'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (src == null) return;

    final XFile? picked = await _picker.pickImage(
      source: src,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageData = bytes;
      _existingPhotoUrl = null;
    });

    _scheduleAutoSave();
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
      _addedExtraFields.clear();
      _availableExtraFields.removeWhere((_) => false);
      _availableExtraFields
          .where((f) {
            switch (f) {
              case 'Drugi numer':
                return (_extraNumbers.isNotEmpty);
              case 'Adres':
                return _addressCtrl.text.trim().isNotEmpty;
              case 'WWW':
                return _websiteCtrl.text.trim().isNotEmpty;
              case 'Notatka':
                return _noteCtrl.text.trim().isNotEmpty;
              default:
                return false;
            }
          })
          .toList()
          .forEach((f) {
            _addedExtraFields.add(f);
            _availableExtraFields.remove(f);
          });

      if (_addedExtraFields.contains('Drugi numer') &&
          _extraNumbers.isNotEmpty) {
        _secondPhoneCtrl.text = _extraNumbers.removeAt(0);
      }
      final projectIds = List<String>.from(data['linkedProjectIds'] ?? []);
      setState(() => _selectedProjectIds = projectIds);
    }
    setState(() => _loading = false);

    await _checkIfPrimaryClient();
  }

  Future<String?> _uploadPhoto(String id) async {
    if (_imageData == null) return null;
    final ref = FirebaseStorage.instance.ref('contacts/$id/photo.jpg');
    await ref.putData(_imageData!);
    return await ref.getDownloadURL();
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

  Future<void> _addProject() async {
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

    setState(() => _isPrimaryContact = true);

    await FirebaseFirestore.instance.collection('contacts').doc(_contactId).set(
      {'linkedCustomerId': _customerId},
      SetOptions(merge: true),
    );
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

  Future<void> _legacySaveAndPop() async {
    _submitting = true;
    await _autoSave();
    await _finalizeImage();
    if (!mounted) return;

    if (_customerId != null && _contactId != null) {
      final custSnap = await FirebaseFirestore.instance
          .collection('customers')
          .doc(_customerId)
          .get();
      final custData = custSnap.data();
      if (custData != null && custData['contactId'] == _contactId) {
        final name = _nameCtrl.text.trim();
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(_customerId)
            .set({
              'name': name,
              'nameFold': name.toLowerCase(),
            }, SetOptions(merge: true));
      }
    }
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
    _secondPhoneCtrl.dispose();
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

    final isClientRecord =
        _isPrimaryContact ||
        _category == 'Klient' ||
        (_isNewClient && widget.forceAsContact == false);

    if (isClientRecord && _customerId != null && _contactId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(
            customerId: _customerId!,
            isAdmin: widget.isAdmin,
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _deleteContact() async {
    if (_contactId == null) return;
    final contactName = _nameCtrl.text.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń kontakt?'),
        content: Text(contactName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('contacts')
        .doc(_contactId)
        .delete();

    if (_isPrimaryContact && _customerId != null) {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(_customerId)
          .delete();
    }

    Navigator.pop(context);
  }

  Future<void> _showProjectMultiSelectDialog() async {
    final tempSet = Set<String>.from(_selectedProjectIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    AppBar(
                      title: const Text('Przypisz do projekty:'),
                      automaticallyImplyLeading: true,
                      elevation: 1,
                    ),

                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _allProjects.length,
                        itemBuilder: (context, index) {
                          final doc = _allProjects[index];
                          final title = (doc.data()['title'] as String);
                          final checked = tempSet.contains(doc.id);

                          return CheckboxListTile(
                            title: Text(title),
                            value: checked,
                            activeColor: Colors.white,
                            checkColor: Colors.green,
                            tileColor: index.isEven
                                ? Colors.grey.shade200
                                : null,
                            onChanged: (on) {
                              setModalState(() {
                                if (on == true) {
                                  tempSet.add(doc.id);
                                } else {
                                  tempSet.remove(doc.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 40,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Anuluj'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedProjectIds = tempSet.toList();
                              });
                              _scheduleAutoSave();
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: AppScaffold(
        title: _isPrimaryContact
            ? 'Edytuj Klient'
            : _isNewClient
            ? 'Dodaj Klienta'
            : widget.contactId == null
            ? 'Dodaj Kontakt'
            : 'Edytuj Kontakt',

        centreTitle: true,

        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _isEditing
            ? FloatingActionButton(
                tooltip: 'Usuń kontakt',
                onPressed: _deleteContact,
                child: const Icon(Icons.delete, color: Colors.red),
              )
            : null,

        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : DismissKeyboard(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // === Avatar Picker (always) ===
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
                                  _imageData == null &&
                                      _existingPhotoUrl == null
                                  ? const Icon(Icons.camera_alt, size: 48)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // === Typ Kontaktu (hide on add client) ===
                          if (!_isPrimaryContact && !_isNewClient) ...[
                            // === Assign to project ===
                            if (widget.linkedCustomerId == null) ...[
                              _projectsLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: const Text(
                                                  'Przypisz do projekt?',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                ),
                                                tooltip: 'Wybierz projekty',
                                                onPressed:
                                                    _showProjectMultiSelectDialog,
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 1),

                                          // ─── Vertical list  ───
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: _selectedProjectIds.map((
                                              projId,
                                            ) {
                                              final title =
                                                  _allProjects
                                                          .firstWhere(
                                                            (d) =>
                                                                d.id == projId,
                                                          )
                                                          .data()['title']
                                                      as String;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 1,
                                                ),
                                                child: InputChip(
                                                  label: Text(title),
                                                  onDeleted: () {
                                                    setState(
                                                      () => _selectedProjectIds
                                                          .remove(projId),
                                                    );
                                                    _scheduleAutoSave();
                                                  },
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),

                              const SizedBox(height: 6),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _categories.contains(_category)
                                        ? _category
                                        : null,
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
                          ],

                          // === Name Field (always) ===
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
                                          ? 'Wpisz nazwa'
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
                                  ? 'Wpisz nazwa'
                                  : null,
                              onChanged: (_) => _scheduleAutoSave(),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // === Telefon (always) ===
                          TextFormField(
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
                          const SizedBox(height: 12),

                          // === Email (always) ===
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wpisz email'
                                : null,
                            onChanged: (_) => _scheduleAutoSave(),
                          ),
                          const SizedBox(height: 12),

                          // === Dropdown extras ===
                          DropdownButtonFormField<String>(
                            key: ValueKey(_availableExtraFields.length),
                            value: null,
                            decoration: const InputDecoration(
                              labelText: 'Dodaj pole...',
                            ),
                            items: _availableExtraFields
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ),
                                )
                                .toList(),
                            onChanged: (f) {
                              if (f == null) return;
                              setState(() {
                                _addedExtraFields.add(f);
                                _availableExtraFields.remove(f);
                              });
                            },
                          ),

                          // === Render any extra fields the user added ===
                          for (var field in _addedExtraFields) ...[
                            if (field == 'Drugi numer') ...[
                              TextFormField(
                                controller: _secondPhoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Drugi numer',
                                ),
                                keyboardType: TextInputType.phone,
                                onChanged: (_) => _scheduleAutoSave(),
                              ),
                              const SizedBox(height: 12),
                            ] else if (field == 'Adres') ...[
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Adres',
                                ),
                                onChanged: (_) => _scheduleAutoSave(),
                              ),
                              const SizedBox(height: 12),
                            ] else if (field == 'WWW') ...[
                              TextFormField(
                                controller: _websiteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'WWW',
                                ),
                                keyboardType: TextInputType.url,
                                onChanged: (_) => _scheduleAutoSave(),
                              ),
                              const SizedBox(height: 12),
                            ] else if (field == 'Notatka') ...[
                              TextFormField(
                                controller: _noteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Notatka',
                                  alignLabelWithHint: true,
                                ),
                                minLines: 1,
                                maxLines: 4,
                                onChanged: (_) => _scheduleAutoSave(),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],

                          const SizedBox(height: 24),

                          if (!_isEditing && _customerId != null) ...[
                            AutoSizeText(
                              'Projekty',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              minFontSize: 15,
                              maxLines: 1,
                            ),

                            Divider(),
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
                            const SizedBox(height: 80),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
