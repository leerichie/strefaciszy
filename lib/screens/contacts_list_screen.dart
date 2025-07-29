// lib/screens/contacts_list_screen.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/add_contact_screen.dart';
import 'package:strefa_ciszy/screens/contact_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_detail_screen.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/main_menu_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController = TextEditingController();
    _updateStream();
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
    var name = data['name'] as String? ?? '';
    var phone = data['phone'] as String? ?? '';
    var email = data['email'] as String? ?? '';
    var type = data['contactType'] as String? ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj kontakt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: 'Imię i nazwisko'),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              await docSnap.reference.update({
                'name': name,
                'phone': phone,
                'email': email,
                'contactType': type,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Zapisz'),
          ),
        ],
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
          // forceAsContact: true,
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
          ),
        ),
      ),

      body: Column(
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: (() {
                Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
                    .collection('contacts');
                if (_category != 'Wszyscy') {
                  ref = ref.where('contactType', isEqualTo: _category);
                }
                if (widget.customerId != null) {
                  ref = ref.where(
                    'linkedCustomerId',
                    isEqualTo: widget.customerId,
                  );
                }
                return ref.orderBy('name').snapshots();
              })(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data!.docs.where((doc) {
                  final name =
                      doc.data()['name']?.toString().toLowerCase() ?? '';
                  return name.contains(_search.toLowerCase());
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('Brak kontaktów.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final contactType = (data['contactType'] as String?) ?? '';

                    return ListTile(
                      title: Text(
                        data['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((data['phone'] ?? '').isNotEmpty) ...[
                            InkWell(
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
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((data['phone'] ?? '').isNotEmpty &&
                              (data['email'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                          ],
                          if ((data['email'] ?? '').isNotEmpty) ...[
                            InkWell(
                              onTap: () => _openUri(
                                Uri.parse('mailto:${data['email']}'),
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
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
