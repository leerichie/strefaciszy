// lib/screens/contacts_list_screen.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contact_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsListScreen extends StatefulWidget {
  final bool isAdmin;
  final String? customerId;
  const ContactsListScreen({super.key, this.isAdmin = false, this.customerId});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  String _search = '';
  List<String> _categories = ['Wszyscy'];
  String _category = 'Wszyscy';

  late final TextEditingController _searchController;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allProjects = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.customerId != null) {
      _loadProjectsUnderCustomer();
    }
    _searchController = TextEditingController();
    _updateStream();
  }

  Future<void> _loadProjectsUnderCustomer() async {
    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId!)
        .collection('projects')
        .orderBy('title')
        .get();
    setState(() {
      _allProjects = snap.docs;
    });
  }

  Future<void> _loadCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('metadata')
        .doc('contactTypes')
        .get();
    final types = List<String>.from((snap.data()!['types'] as List));
    setState(() {
      _categories = ['Wszyscy', ...types];
    });
  }

  void _updateStream() {
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance.collection(
      'contacts',
    );
    if (_category.isNotEmpty && _category != 'Wszyscy') {
      ref = ref.where('contactType', isEqualTo: _category);
    }
    _stream = ref.orderBy('name').snapshots().handleError((e) {
      print('Firestore error: $e');
    });
  }

  Future<void> _showEditContactDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> docSnap,
  ) async {
    final data = docSnap.data();
    final custId = data['linkedCustomerId'] as String?;
    final projQuery = FirebaseFirestore.instance.collectionGroup('projects');

    final projSnap = await projQuery.orderBy('title').get();
    final allProjects = projSnap.docs;

    final tempSet = Set<String>.from(
      List<String>.from(data['linkedProjectIds'] ?? <String>[]),
    );

    var name = data['name'] as String? ?? '';
    var phone = data['phone'] as String? ?? '';
    var email = data['email'] as String? ?? '';
    var type = data['contactType'] as String? ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Edytuj kontakt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    labelText: 'Imię i nazwisko',
                  ),
                  onChanged: (v) => name = v.trim(),
                ),
                TextFormField(
                  initialValue: phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => phone = v.trim(),
                ),
                TextFormField(
                  initialValue: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => email = v.trim(),
                ),
                TextFormField(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Typ kontaktu'),
                  onChanged: (v) => type = v.trim(),
                ),

                // ─── ONLY show  iFFFFFF
                // if (custId != null) ...[
                const SizedBox(height: 5),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Przypisz do projekty?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Wybierz projekty',
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: ctx,
                          isScrollControlled: true,
                          builder: (_) => StatefulBuilder(
                            builder: (_, sheetSetState) =>
                                DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.7,
                                  builder: (_, controller) => Column(
                                    children: [
                                      AppBar(
                                        title: const Text('Wybierz projekty:'),
                                        automaticallyImplyLeading: true,
                                        elevation: 1,
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          controller: controller,
                                          itemCount: allProjects.length,
                                          itemBuilder: (_, i) {
                                            final p = allProjects[i];
                                            final title =
                                                (p.data()['title'] as String);
                                            final checked = tempSet.contains(
                                              p.id,
                                            );

                                            return CheckboxListTile(
                                              tileColor: i.isEven
                                                  ? Colors.grey.shade200
                                                  : null,
                                              title: Text(title),
                                              value: checked,
                                              activeColor: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              checkColor: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              onChanged: (on) {
                                                sheetSetState(() {
                                                  if (on == true) {
                                                    tempSet.add(p.id);
                                                  } else {
                                                    tempSet.remove(p.id);
                                                  }
                                                });
                                                setModalState(() {});
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                ...tempSet.map((projId) {
                  final title =
                      allProjects
                              .firstWhere((d) => d.id == projId)
                              .data()['title']
                          as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: InputChip(
                      label: Text(title),
                      onDeleted: () => setModalState(() {
                        tempSet.remove(projId);
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            if (widget.isAdmin)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('Na pewno usunac kontakt?'),
                      content: Text(data['name'] ?? ''),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx2, false),
                          child: const Text('Anuluj'),
                        ),
                        ElevatedButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(ctx2, true),
                          child: const Text('Usuń'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;

                  await docSnap.reference.delete();
                  Navigator.of(ctx).pop();
                },
                child: const Text('Usuń'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatePayload = <String, dynamic>{
                  'name': name,
                  'phone': phone,
                  'email': email,
                  'contactType': type,
                  'linkedProjectIds': tempSet.toList(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (tempSet.isEmpty) {
                  updatePayload['linkedCustomerId'] = FieldValue.delete();
                } else {
                  if (custId != null) {
                    updatePayload['linkedCustomerId'] = custId;
                  } else {
                    final firstProj = allProjects.firstWhere(
                      (p) => p.id == tempSet.first,
                    );
                    final parentCustomerDoc = firstProj.reference.parent.parent;
                    if (parentCustomerDoc != null) {
                      updatePayload['linkedCustomerId'] = parentCustomerDoc.id;
                    }
                  }
                }

                await docSnap.reference.update(updatePayload);
                Navigator.of(ctx).pop();
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addContact() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(
          isAdmin: widget.isAdmin,
          linkedCustomerId: widget.customerId,
        ),
      ),
    );
  }

  Future<void> _openUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $uri')));
    }
  }

  Widget _buildCategoryChip(String label) {
    final selected = _category == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _category = selected ? '' : label;
          _updateStream();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget dynamicTitleWidget = widget.customerId == null
        ? const AutoSizeText(
            'Kontakty',
            style: TextStyle(fontSize: 16),
            minFontSize: 9,
            maxLines: 1,
          )
        : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.customerId!)
                .get(),

            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done ||
                  !snap.hasData ||
                  snap.data!.data() == null) {
                return const Text('Kontakty');
              }
              final clientName = snap.data!.data()!['name'] as String? ?? '';
              return Text(
                'Kontakty: $clientName',
                style: TextStyle(fontSize: 16),
              );
            },
          );

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dodaj Kontakt',
        onPressed: _addContact,
        child: const Icon(Icons.person_add_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      title: 'Kontakty',
      titleWidget: dynamicTitleWidget,
      centreTitle: true,

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Szukaj…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
      ),

      body: DismissKeyboard(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Typ kontaktu',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                value: _category == 'Wszyscy' ? null : _category,
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat == 'Wszyscy' ? '' : cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _category = (v == null || v.isEmpty) ? 'Wszyscy' : v;
                  _updateStream();
                }),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: widget.customerId != null
                  ? FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('customers')
                          .doc(widget.customerId!)
                          .collection('projects')
                          .get(),
                      builder: (ctx, projSnap) {
                        if (!projSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final projectIds = projSnap.data!.docs
                            .map((d) => d.id)
                            .toList();

                        Query<Map<String, dynamic>> ref = FirebaseFirestore
                            .instance
                            .collection('contacts');

                        if (_category != 'Wszyscy') {
                          ref = ref.where('contactType', isEqualTo: _category);
                        }

                        if (projectIds.isEmpty) {
                          ref = ref.where(
                            'linkedCustomerId',
                            isEqualTo: widget.customerId,
                          );
                        } else {
                          ref = ref.where(
                            Filter.or(
                              Filter(
                                'linkedCustomerId',
                                isEqualTo: widget.customerId,
                              ),
                              Filter(
                                'linkedProjectIds',
                                arrayContainsAny: projectIds,
                              ),
                            ),
                          );
                        }

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: ref.orderBy('name').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }
                            final docs = snapshot.data!.docs.where((doc) {
                              final name =
                                  doc
                                      .data()['name']
                                      ?.toString()
                                      .toLowerCase() ??
                                  '';
                              return name.contains(_search.toLowerCase());
                            }).toList();
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text('Brak kontaktów.'),
                              );
                            }
                            return NotificationListener<ScrollNotification>(
                              onNotification: (notif) {
                                if (notif is ScrollStartNotification) {
                                  FocusScope.of(context).unfocus();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: docs.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final doc = docs[i];
                                  final data = doc.data();
                                  final contactType =
                                      (data['contactType'] as String?) ?? '';

                                  return GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () {
                                      if (contactType.toLowerCase() ==
                                          'klient') {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CustomerDetailScreen(
                                                  customerId: doc.id,
                                                  isAdmin: widget.isAdmin,
                                                ),
                                          ),
                                        );
                                      } else {
                                        _showEditContactDialog(context, doc);
                                      }
                                    },
                                    child: ListTile(
                                      title: Text(
                                        data['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if ((data['phone'] ?? '')
                                              .isNotEmpty) ...[
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _openUri(
                                                Uri.parse(
                                                  'tel:${data['phone']}',
                                                ),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.phone,
                                                      size: 15,
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      data['phone']!,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          if ((data['phone'] ?? '')
                                                  .isNotEmpty &&
                                              (data['email'] ?? '').isNotEmpty)
                                            const SizedBox(height: 4),
                                          if ((data['email'] ?? '')
                                              .isNotEmpty) ...[
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _openUri(
                                                Uri.parse(
                                                  'mailto:${data['email']}',
                                                ),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.email,
                                                      size: 15,
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      data['email']!,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: Text(contactType),
                                      onTap: () {
                                        if (contactType.toLowerCase() ==
                                            'klient') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ContactDetailScreen(
                                                    contactId: doc.id,
                                                    isAdmin: widget.isAdmin,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          _showEditContactDialog(context, doc);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: (() {
                        Query<Map<String, dynamic>> ref = FirebaseFirestore
                            .instance
                            .collection('contacts');
                        if (_category != 'Wszyscy') {
                          ref = ref.where('contactType', isEqualTo: _category);
                        }
                        return ref.orderBy('name').snapshots();
                      })(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final docs = snapshot.data!.docs.where((doc) {
                          final name =
                              doc.data()['name']?.toString().toLowerCase() ??
                              '';
                          return name.contains(_search.toLowerCase());
                        }).toList();
                        if (docs.isEmpty) {
                          return const Center(child: Text('Brak kontaktów.'));
                        }
                        return NotificationListener<ScrollNotification>(
                          onNotification: (notif) {
                            if (notif is ScrollStartNotification) {
                              FocusScope.of(context).unfocus();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data();
                              final contactType =
                                  (data['contactType'] as String?) ?? '';

                              return GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () {
                                  if (contactType.toLowerCase() == 'klient') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerDetailScreen(
                                          customerId: doc.id,
                                          isAdmin: widget.isAdmin,
                                        ),
                                      ),
                                    );
                                  } else {
                                    _showEditContactDialog(context, doc);
                                  }
                                },
                                child: ListTile(
                                  title: Text(
                                    data['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if ((data['phone'] ?? '').isNotEmpty) ...[
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openUri(
                                            Uri.parse('tel:${data['phone']}'),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.phone,
                                                  size: 15,
                                                  color: Colors.green,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  data['phone']!,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      if ((data['phone'] ?? '').isNotEmpty &&
                                          (data['email'] ?? '').isNotEmpty)
                                        const SizedBox(height: 4),
                                      if ((data['email'] ?? '').isNotEmpty) ...[
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openUri(
                                            Uri.parse(
                                              'mailto:${data['email']}',
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.email,
                                                  size: 15,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  data['email']!,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Text(contactType),
                                  onTap: () {
                                    if (contactType.toLowerCase() == 'klient') {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ContactDetailScreen(
                                            contactId: doc.id,
                                            isAdmin: widget.isAdmin,
                                          ),
                                        ),
                                      );
                                    } else {
                                      _showEditContactDialog(context, doc);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
